#include "mex.h"
static unsigned int crc_table[256];
static int initialised = 0;
void crc32_setup(void) {
    unsigned int i, j, k;
    for (i = 0; i < 256; i++) {
        k = i;
        for (j = 0; j < 8; j++) {
            if (k & 1) k = (k >> 1) ^ 0xEDB88320;
            else k >>= 1;
        }
        crc_table[i] = k;
    }
}
void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[]) {
    unsigned int crc = 0xFFFFFFFF;
    unsigned char *data;
    size_t len, i;
    if (!initialised) { crc32_setup(); initialised = 1; }
    data = (unsigned char *)mxGetData(prhs[0]);
    len = mxGetNumberOfElements(prhs[0]);
    for (i = 0; i < len; i++) {
        crc = (crc >> 8) ^ crc_table[(crc ^ data[i]) & 0xFF];
    }
    crc ^= 0xFFFFFFFF;
    plhs[0] = mxCreateNumericMatrix(1, 1, mxUINT32_CLASS, mxREAL);
    *(unsigned int *)mxGetData(plhs[0]) = crc;
}