-module(ar_poller_worker).

-behaviour(gen_server).

-export([start_link/1]).

-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-include_lib("arweave/include/ar.hrl").
-include_lib("arweave/include/ar_config.hrl").

-record(state, {
	peer,
	polling_frequency_ms,
	pause = false
}).

%%%===================================================================
%%% Public interface.
%%%===================================================================

start_link(Name) ->
	gen_server:start_link({local, Name}, ?MODULE, [], []).

%%%===================================================================
%%% gen_server callbacks.
%%%===================================================================

init([]) ->
	process_flag(trap_exit, true),
	{ok, Config} = application:get_env(arweave, config),
	[ok] = ar_events:subscribe([node_state]),
	{ok, #state{ polling_frequency_ms = Config#config.polling * 1000 }}.

handle_call(Request, _From, State) ->
	?LOG_WARNING("event: unhandled_call, request: ~p", [Request]),
	{reply, ok, State}.

handle_cast(poll, #state{ peer = undefined } = State) ->
	ar_util:cast_after(1000, self(), poll),
	{noreply, State};
handle_cast(poll, #state{ peer = Peer, polling_frequency_ms = FrequencyMs } = State) ->
	case ar_http_iface_client:get_recent_hash_list_diff(Peer) of
		{ok, in_sync} ->
			ar_util:cast_after(FrequencyMs, self(), poll),
			{noreply, State};
		{ok, {H, TXIDs}} ->
			case ar_ignore_registry:member(H) of
				true ->
					ok;
				false ->
					Indices = get_missing_tx_indices(TXIDs),
					case ar_http_iface_client:get_block(Peer, H, Indices) of
						{B, Time, Size} ->
							case collect_missing_transactions(B#block.txs) of
								{ok, TXs} ->
									B2 = B#block{ txs = TXs },
									ar_events:send(block, {discovered, Peer, B2, Time, Size}),
									ok;
								failed ->
									ok
							end;
						Error ->
							?LOG_DEBUG([{event, failed_to_fetch_block},
									{peer, ar_util:format_peer(Peer)},
									{block, ar_util:encode(H)},
									{error, io_lib:format("~p", [Error])}]),
							ok
					end
			end,
			ar_util:cast_after(FrequencyMs, self(), poll),
			{noreply, State};
		{error, request_type_not_found} ->
			{noreply, State#state{ pause = true }};
		{error, not_found} ->
			?LOG_WARNING([{event, peer_behind_or_deviated}, {peer, ar_util:format_peer(Peer)}]),
			{noreply, State#state{ pause = true }};
		Error ->
			?LOG_DEBUG([{event, failed_to_fetch_recent_hash_list_diff},
					{peer, ar_util:format_peer(Peer)}, {error, io_lib:format("~p", [Error])}]),
			{noreply, State#state{ pause = true }}
	end;

handle_cast({set_peer, Peer}, #state{ pause = Pause } = State) ->
	case Pause of
		true ->
			gen_server:cast(self(), poll);
		false ->
			ok
	end,
	{noreply, State#state{ peer = Peer, pause = false }};

handle_cast(Msg, State) ->
	?LOG_ERROR([{event, unhandled_cast}, {module, ?MODULE}, {message, Msg}]),
	{noreply, State}.

handle_info({event, node_state, initialized}, State) ->
	gen_server:cast(self(), poll),
	{noreply, State};

handle_info({event, node_state, _}, State) ->
	{noreply, State};

handle_info({gun_down, _, http, normal, _, _}, State) ->
	{noreply, State};
handle_info({gun_down, _, http, closed, _, _}, State) ->
	{noreply, State};
handle_info({gun_up, _, http}, State) ->
	{noreply, State};

handle_info(Info, State) ->
	?LOG_ERROR([{event, unhandled_info}, {module, ?MODULE}, {info, Info}]),
	{noreply, State}.

terminate(_Reason, _State) ->
	ok.

%%%===================================================================
%%% Private functions.
%%%===================================================================

get_missing_tx_indices(TXIDs) ->
	get_missing_tx_indices(TXIDs, 0).

get_missing_tx_indices([], _N) ->
	[];
get_missing_tx_indices([TXID | TXIDs], N) ->
	case ets:member(node_state, {tx, TXID}) of
		true ->
			get_missing_tx_indices(TXIDs, N + 1);
		false ->
			[N | get_missing_tx_indices(TXIDs, N + 1)]
	end.

collect_missing_transactions([#tx{} = TX | TXs]) ->
	case collect_missing_transactions(TXs) of
		failed ->
			failed;
		{ok, TXs2} ->
			{ok, [TX | TXs2]}
	end;
collect_missing_transactions([TXID | TXs]) ->
	case ets:lookup(node_state, {tx, TXID}) of
		[] ->
			failed;
		[{_, TX}] ->
			collect_missing_transactions([TX | TXs])
	end;
collect_missing_transactions([]) ->
	{ok, []}.
