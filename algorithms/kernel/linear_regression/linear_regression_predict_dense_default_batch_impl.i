/* file: linear_regression_predict_dense_default_batch_impl.i */
/*******************************************************************************
* Copyright 2014-2016 Intel Corporation
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
*     http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*******************************************************************************/

/*
//++
//  Common functions for linear regression predictions calculation
//--
*/

#ifndef __LINEAR_REGRESSION_PREDICT_DENSE_DEFAULT_BATCH_IMPL_I__
#define __LINEAR_REGRESSION_PREDICT_DENSE_DEFAULT_BATCH_IMPL_I__

#include "algorithm.h"
#include "numeric_table.h"
#include "linear_regression_training_batch.h"
#include "linear_regression_training_online.h"
#include "linear_regression_training_distributed.h"
#include "linear_regression_ne_model.h"
#include "threading.h"
#include "daal_defines.h"
#include "service_blas.h"

using namespace daal::internal;

namespace daal
{
namespace algorithms
{
namespace linear_regression
{
namespace prediction
{
namespace internal
{

/**
 *  \brief Function that computes linear regression prediction results
 *         for a block of input data rows
 *
 *  \param numFeatures[in]      Number of features in input data row
 *  \param numRows[in]          Number of input data rows
 *  \param dataBlock[in]        Block of input data rows
 *  \param numBetas[in]         Number of regression coefficients
 *  \param beta[in]             Regression coefficients
 *  \param numResponses[in]     Number of responses to calculate for each input data row
 *  \param responseBlock[out]   Resulting block of responses
 *  \param findBeta0[in]        Flag. True if regression coefficient contain intercept term;
 *                              false - otherwise.
 *
 *  \return Execuation if(!this->_errors->isEmpty())
 */
template<typename interm, CpuType cpu>
void LinearRegressionPredictKernel<interm, defaultDense, cpu>::computeBlockOfResponses(
            MKL_INT *numFeatures, MKL_INT *numRows, interm *dataBlock,
            MKL_INT *numBetas, interm *beta,
            MKL_INT *numResponses, interm *responseBlock, bool findBeta0)
{
    /* GEMM parameters */
    char trans   = 'T';
    char notrans = 'N';
    interm one  = 1.0;
    interm zero = 0.0;

    Blas<interm, cpu>::xxgemm(&trans, &notrans, numResponses, numRows, numFeatures,
                       &one, beta + 1, numBetas, dataBlock, numFeatures, &zero,
                       responseBlock, numResponses);

    if (findBeta0)
    {
        /* Add intercept term to linear regression results */
        MKL_INT iZero = 0;
        MKL_INT numFeaturesValue  = *numFeatures;
        MKL_INT numBetasValue     = *numBetas;
        MKL_INT numResponsesValue = *numResponses;
        for (MKL_INT j = 0; j < numResponsesValue; j++)
        {
            Blas<interm, cpu>::xxaxpy(numRows, &one, beta + j * numBetasValue, &iZero,
                               responseBlock + j, numResponses);
        }
    } /* if (findBeta0) */
} /* void LinearRegressionPredictKernel<interm, defaultDense, cpu>::computeBlockOfResponses */


template<typename interm, CpuType cpu>
void LinearRegressionPredictKernel<interm, defaultDense, cpu>::compute(
            const NumericTable *a, const daal::algorithms::Model *m, NumericTable *r,
            const daal::algorithms::Parameter *par)
{
    const linear_regression::Parameter *parameter = static_cast<const linear_regression::Parameter *>(par);

    Model *model = static_cast<Model *>(const_cast<daal::algorithms::Model *>(m));

    /* Get numeric tables with input data */
    NumericTable *dataTable = const_cast<NumericTable *>(a);

    /* Get numeric table to store results */

    bool findBeta0 = true;
    if (parameter && !parameter->interceptFlag)
    {
        /* Here if intercept term won't be calculated  */
        findBeta0 = false;
    };
    MKL_INT numVectors  = dataTable->getNumberOfRows();

    /* Get linear regression coefficients */
    NumericTable *betaTable = model->getBeta().get();
    MKL_INT numResponses = betaTable->getNumberOfRows();
    BlockDescriptor<interm> betaBD;

    /* Retrieve data associated with coefficients */
    betaTable->getBlockOfRows(0, numResponses, readOnly, betaBD);
    interm *beta = betaBD.getBlockPtr();

    size_t numRowsInBlock = 256;
    if (numRowsInBlock < 1) { numRowsInBlock = 1; }

    /* Calculate number of blocks of rows including tail block */
    size_t numBlocks = numVectors / numRowsInBlock;
    if (numBlocks * numRowsInBlock < numVectors) { numBlocks++; }

    /* Loop over input data blocks */
    daal::threader_for( numBlocks, numBlocks, [ = ](int iBlock)
    {

        size_t startRow = iBlock * numRowsInBlock;
        size_t endRow = startRow + numRowsInBlock;
        if (endRow > numVectors) { endRow = numVectors; }

        MKL_INT numRows = endRow - startRow;

        MKL_INT numFeatures = dataTable->getNumberOfColumns();
        MKL_INT nAllBetas   = betaTable->getNumberOfColumns();

        /* Retrieve data blocks associated with input and resulting tables */
        interm *dataBlock, *responseBlock;

        BlockDescriptor<interm> dataBM;
        dataTable->getBlockOfRows(startRow, endRow, readOnly,  dataBM);
        dataBlock = dataBM.getBlockPtr();

        BlockDescriptor<interm> responseBM;
        r->getBlockOfRows(startRow, endRow, writeOnly, responseBM);
        responseBlock = responseBM.getBlockPtr();
        MKL_INT*  pnumResponses = (MKL_INT*)&numResponses;

        /* Calculate predictions */
        computeBlockOfResponses(&numFeatures, &numRows, dataBlock, &nAllBetas,
                                beta, pnumResponses, responseBlock, findBeta0);

        dataTable->releaseBlockOfRows(dataBM);
        r->releaseBlockOfRows(responseBM);

      } ); /* daal::threader_for */

    betaTable->releaseBlockOfRows(betaBD);

} /* void LinearRegressionPredictKernel<interm, defaultDense, cpu>::compute */

} /* namespace internal */
} /* namespace prediction */
} /* namespace linear_regression */
} /* namespace algorithms */
} /* namespace daal */

#endif
