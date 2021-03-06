/* file: split_layer_backward_batch_container.h */
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
//  Implementation of split layer container.
//--
*/

#ifndef __SPLIT_LAYER_BACKWARD_BATCH_CONTAINER_H__
#define __SPLIT_LAYER_BACKWARD_BATCH_CONTAINER_H__

#include "neural_networks/layers/split/split_layer.h"
#include "split_layer_backward_kernel.h"

namespace daal
{
namespace algorithms
{
namespace neural_networks
{
namespace layers
{
namespace split
{
namespace backward
{
namespace interface1
{
template<typename algorithmFPType, Method method, CpuType cpu>
BatchContainer<algorithmFPType, method, cpu>::BatchContainer(daal::services::Environment::env *daalEnv)
{
    __DAAL_INITIALIZE_KERNELS(internal::SplitKernel, algorithmFPType, method);
}

template<typename algorithmFPType, Method method, CpuType cpu>
BatchContainer<algorithmFPType, method, cpu>::~BatchContainer()
{
    __DAAL_DEINITIALIZE_KERNELS();
}

template<typename algorithmFPType, Method method, CpuType cpu>
void BatchContainer<algorithmFPType, method, cpu>::compute()
{
    split::backward::Input *input = static_cast<split::backward::Input *>(_in);
    split::backward::Result *result = static_cast<split::backward::Result *>(_res);

    split::Parameter *parameter = static_cast<split::Parameter *>(_par);
    daal::services::Environment::env &env = *_env;

    __DAAL_CALL_KERNEL(env, internal::SplitKernel, __DAAL_KERNEL_ARGUMENTS(algorithmFPType, method), compute, input, parameter,
                       result);
}
} // namespace interface1
} // namespace backward

} // namespace split
} // namespace layers
} // namespace neural_networks
} // namespace algorithms
} // namespace daal

#endif
