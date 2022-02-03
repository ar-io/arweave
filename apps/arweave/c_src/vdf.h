#include <stdbool.h>
#include <gmp.h>
#include "randomx.h"

const int WALLET_SIZE = 32;
// const int VDF_SHA_HASH_SIZE = 32;
// This required for mixed sha+randomx, because possible different seed sizes.
const int VDF_SHA_HASH_SIZE = RANDOMX_HASH_SIZE;
// const int VDF_MIMC_SIZE = 32;
const int VDF_MIMC_SIZE = RANDOMX_HASH_SIZE;

#if defined(__cplusplus)
extern "C" {
#endif

void vdf_sha2(unsigned char* walletBuffer, unsigned char* seed, unsigned char* out, unsigned char* outCheckpoint, int checkpointCount, int hashingIterations);
bool vdf_parallel_sha_verify(unsigned char* walletBuffer, unsigned char* seed, int checkpointCount, int hashingIterations, unsigned char* inRes, unsigned char* inCheckpoint, int maxThreadCount);

void vdf_randomx(unsigned char* walletBuffer, unsigned char* seed, unsigned char* out, unsigned char* outCheckpoint, int checkpointCount, int hashingIterations, randomx_vm *vmPtr);
bool vdf_parallel_randomx_verify(unsigned char* walletBuffer, unsigned char* seed, int checkpointCount, int hashingIterations,
	unsigned char* inRes, unsigned char* inCheckpoint, int maxThreadCount, randomx_dataset* datasetPtr, randomx_cache* cachePtr, randomx_vm *vmPtr, randomx_flags flags);


void vdf_parallel_sha_randomx(unsigned char* walletBuffer, unsigned char* seed, unsigned char* out, unsigned char* outCheckpoint, int checkpointCount,
	int hashingIterationsSha, int hashingIterationsRandomx, randomx_vm *vmPtr);
bool vdf_parallel_sha_randomx_verify(unsigned char* walletBuffer, unsigned char* seed, int checkpointCount, int hashingIterationsSha, int hashingIterationsRandomx,
	unsigned char* inRes, unsigned char* inCheckpoint, int maxThreadCount, randomx_dataset* datasetPtr, randomx_cache* cachePtr, randomx_vm *vmPtr, randomx_flags flags);

void vdf_mimc_init(mpz_t modulus, mpz_t pow);
void vdf_mimc_import(unsigned char* seed, unsigned char* out);
void vdf_mimc_slow(unsigned char* seed, unsigned char* out, int iterations);
bool vdf_mimc_verify(unsigned char* seed, unsigned char* out, int iterations);

#if defined(__cplusplus)
}
#endif
