﻿#include "DataAccessKernels.cuh"

namespace
{
    __device__ void copyBytes(int& targetLen, uint64_t& targetStringIndex, int sourceLen, char* sourceString, int& numStringBytes, char*& stringBytes)
    {
        targetLen = sourceLen;
        if (sourceLen > 0) {
            targetStringIndex = atomicAdd(&numStringBytes, sourceLen);
            for (int i = 0; i < sourceLen; ++i) {
                stringBytes[targetStringIndex + i] = sourceString[i];
            }
        }
    }

    __device__ void createCellTO(Cell* cell, DataTO& dataTO, Cell* cellArrayStart)
    {
        auto cellTOIndex = atomicAdd(dataTO.numCells, 1);
        auto& cellTO = dataTO.cells[cellTOIndex];

        cellTO.id = cell->id;
        cellTO.pos = cell->absPos;
        cellTO.vel = cell->vel;
        cellTO.barrier = cell->barrier;
        cellTO.energy = cell->energy;
        cellTO.maxConnections = cell->maxConnections;
        cellTO.numConnections = cell->numConnections;
        cellTO.executionOrderNumber = cell->executionOrderNumber;
        cellTO.underConstruction = cell->underConstruction;
        cellTO.inputBlocked = cell->inputBlocked;
        cellTO.outputBlocked = cell->outputBlocked;
        cellTO.cellFunction = cell->cellFunction;
        cellTO.color = cell->color;
        cellTO.age = cell->age;

        copyBytes(
            cellTO.metadata.nameSize, cellTO.metadata.nameIndex, cell->metadata.nameSize, cell->metadata.name, *dataTO.numAdditionalData, dataTO.additionalData);
        copyBytes(
            cellTO.metadata.descriptionSize,
            cellTO.metadata.descriptionIndex,
            cell->metadata.descriptionSize,
            cell->metadata.description,
            *dataTO.numAdditionalData,
            dataTO.additionalData);
        copyBytes(
            cellTO.metadata.sourceCodeLen,
            cellTO.metadata.sourceCodeByteIndex,
            cell->metadata.sourceCodeLen,
            cell->metadata.sourceCode,
            *dataTO.numAdditionalData,
            dataTO.additionalData);

        cell->tag = cellTOIndex;
        for (int i = 0; i < cell->numConnections; ++i) {
            auto connectingCell = cell->connections[i].cell;
            cellTO.connections[i].cellIndex = connectingCell - cellArrayStart;
            cellTO.connections[i].distance = cell->connections[i].distance;
            cellTO.connections[i].angleFromPrevious = cell->connections[i].angleFromPrevious;
        }
    }

    __device__ void createParticleTO(Particle* particle, DataTO& dataTO)
    {
        int particleTOIndex = atomicAdd(dataTO.numParticles, 1);
        ParticleTO& particleTO = dataTO.particles[particleTOIndex];

        particleTO.id = particle->id;
        particleTO.pos = particle->absPos;
        particleTO.vel = particle->vel;
        particleTO.energy = particle->energy;
    }

}

/************************************************************************/
/* Main                                                                 */
/************************************************************************/
__global__ void cudaGetSelectedCellDataWithoutConnections(SimulationData data, bool includeClusters, DataTO dataTO)
{
    auto const& cells = data.objects.cellPointers;
    auto const partition = calcAllThreadsPartition(cells.getNumEntries());
    auto const cellArrayStart = data.objects.cells.getArray();

    for (int index = partition.startIndex; index <= partition.endIndex; ++index) {
        auto& cell = cells.at(index);
        if ((includeClusters && cell->selected == 0) || (!includeClusters && cell->selected != 1)) {
            cell->tag = -1;
            continue;
        }
        createCellTO(cell, dataTO, cellArrayStart);
    }
}

__global__ void cudaGetSelectedParticleData(SimulationData data, DataTO access)
{
    PartitionData particleBlock = calcPartition(data.objects.particlePointers.getNumEntries(), threadIdx.x + blockIdx.x * blockDim.x, blockDim.x * gridDim.x);

    for (int particleIndex = particleBlock.startIndex; particleIndex <= particleBlock.endIndex; ++particleIndex) {
        auto const& particle = data.objects.particlePointers.at(particleIndex);
        if (particle->selected == 0) {
            continue;
        }

        createParticleTO(particle, access);
    }
}

__global__ void cudaGetInspectedCellDataWithoutConnections(InspectedEntityIds ids, SimulationData data, DataTO dataTO)
{
    auto const& cells = data.objects.cellPointers;
    auto const partition = calcAllThreadsPartition(cells.getNumEntries());
    auto const cellArrayStart = data.objects.cells.getArray();

    for (int index = partition.startIndex; index <= partition.endIndex; ++index) {
        auto& cell = cells.at(index);

        bool found = false;
        for (int i = 0; i < Const::MaxInspectedEntities; ++i) {
            if (ids.values[i] == 0) {
                break;
            }
            if (ids.values[i] == cell->id) {
                found = true;
            }
        }
        if (!found) {
            cell->tag = -1;
            continue;
        }

        createCellTO(cell, dataTO, cellArrayStart);
    }
}

__global__ void cudaGetInspectedParticleData(InspectedEntityIds ids, SimulationData data, DataTO access)
{
    PartitionData particleBlock = calcAllThreadsPartition(data.objects.particlePointers.getNumEntries());

    for (int particleIndex = particleBlock.startIndex; particleIndex <= particleBlock.endIndex; ++particleIndex) {
        auto const& particle = data.objects.particlePointers.at(particleIndex);
        bool found = false;
        for (int i = 0; i < Const::MaxInspectedEntities; ++i) {
            if (ids.values[i] == 0) {
                break;
            }
            if (ids.values[i] == particle->id) {
                found = true;
            }
        }
        if (!found) {
            continue;
        }

        createParticleTO(particle, access);
    }
}

__global__ void cudaGetOverlayData(int2 rectUpperLeft, int2 rectLowerRight, SimulationData data, DataTO dataTO)
{
    {
        auto const& cells = data.objects.cellPointers;
        auto const partition = calcAllThreadsPartition(cells.getNumEntries());

        for (int index = partition.startIndex; index <= partition.endIndex; ++index) {
            auto& cell = cells.at(index);

            auto pos = cell->absPos;
            data.cellMap.correctPosition(pos);
            if (!isContainedInRect(rectUpperLeft, rectLowerRight, pos)) {
                continue;
            }
            auto cellTOIndex = atomicAdd(dataTO.numCells, 1);
            auto& cellTO = dataTO.cells[cellTOIndex];

            cellTO.id = cell->id;
            cellTO.pos = cell->absPos;
            cellTO.cellFunction = cell->cellFunction;
            cellTO.selected = cell->selected;
            cellTO.executionOrderNumber = cell->executionOrderNumber;
        }
    }
    {
        auto const& particles = data.objects.particlePointers;
        auto const partition = calcAllThreadsPartition(particles.getNumEntries());

        for (int index = partition.startIndex; index <= partition.endIndex; ++index) {
            auto& particle = particles.at(index);

            auto pos = particle->absPos;
            data.particleMap.correctPosition(pos);
            if (!isContainedInRect(rectUpperLeft, rectLowerRight, pos)) {
                continue;
            }
            auto particleTOIndex = atomicAdd(dataTO.numParticles, 1);
            auto& particleTO = dataTO.particles[particleTOIndex];

            particleTO.id = particle->id;
            particleTO.pos = particle->absPos;
            particleTO.selected = particle->selected;
        }
    }
}

//tags cell with cellTO index and tags cellTO connections with cell index
__global__ void cudaGetCellDataWithoutConnections(int2 rectUpperLeft, int2 rectLowerRight, SimulationData data, DataTO dataTO)
{
    auto const& cells = data.objects.cellPointers;
    auto const partition = calcAllThreadsPartition(cells.getNumEntries());
    auto const cellArrayStart = data.objects.cells.getArray();

    for (int index = partition.startIndex; index <= partition.endIndex; ++index) {
        auto& cell = cells.at(index);

        auto pos = cell->absPos;
        data.cellMap.correctPosition(pos);
        if (!isContainedInRect(rectUpperLeft, rectLowerRight, pos)) {
            cell->tag = -1;
            continue;
        }

        createCellTO(cell, dataTO, cellArrayStart);
    }
}

__global__ void cudaResolveConnections(SimulationData data, DataTO dataTO)
{
    auto const partition = calcAllThreadsPartition(*dataTO.numCells);
    auto const firstCell = data.objects.cells.getArray();

    for (int index = partition.startIndex; index <= partition.endIndex; ++index) {
        auto& cellTO = dataTO.cells[index];

        for (int i = 0; i < cellTO.numConnections; ++i) {
            auto const cellIndex = cellTO.connections[i].cellIndex;
            cellTO.connections[i].cellIndex = data.objects.cells.at(cellIndex).tag;
        }
    }
}

__global__ void cudaGetParticleData(int2 rectUpperLeft, int2 rectLowerRight, SimulationData data, DataTO access)
{
    PartitionData particleBlock = calcPartition(data.objects.particlePointers.getNumEntries(), threadIdx.x + blockIdx.x * blockDim.x, blockDim.x * gridDim.x);

    for (int particleIndex = particleBlock.startIndex; particleIndex <= particleBlock.endIndex; ++particleIndex) {
        auto const& particle = data.objects.particlePointers.at(particleIndex);
        auto pos = particle->absPos;
        data.particleMap.correctPosition(pos);
        if (!isContainedInRect(rectUpperLeft, rectLowerRight, pos)) {
            continue;
        }

        createParticleTO(particle, access);
    }
}

__global__ void cudaCreateDataFromTO(SimulationData data, DataTO dataTO, bool selectNewData, bool createIds)
{
    __shared__ ObjectFactory factory;
    if (0 == threadIdx.x) {
        factory.init(&data);
    }
    __syncthreads();

    auto particlePartition = calcPartition(*dataTO.numParticles, threadIdx.x + blockIdx.x * blockDim.x, blockDim.x * gridDim.x);
    for (int index = particlePartition.startIndex; index <= particlePartition.endIndex; ++index) {
        auto particle = factory.createParticleFromTO(dataTO.particles[index], createIds);
        if (selectNewData) {
            particle->selected = 1;
        }
    }

    auto cellPartition = calcPartition(*dataTO.numCells, threadIdx.x + blockIdx.x * blockDim.x, blockDim.x * gridDim.x);
    auto cellTargetArray = data.objects.cells.getArray() + data.objects.cells.getNumOrigEntries();
    for (int index = cellPartition.startIndex; index <= cellPartition.endIndex; ++index) {
        auto cell = factory.createCellFromTO(index, dataTO.cells[index], cellTargetArray, &dataTO, createIds);
        if (selectNewData) {
            cell->selected = 1;
        }
    }
}

__global__ void cudaAdaptNumberGenerator(CudaNumberGenerator numberGen, DataTO dataTO)
{
    {
        auto const partition = calcPartition(*dataTO.numCells, threadIdx.x + blockIdx.x * blockDim.x, blockDim.x * gridDim.x);

        for (int index = partition.startIndex; index <= partition.endIndex; ++index) {
            auto const& cell = dataTO.cells[index];
            numberGen.adaptMaxId(cell.id);
        }
    }
    {
        auto const partition = calcPartition(*dataTO.numParticles, threadIdx.x + blockIdx.x * blockDim.x, blockDim.x * gridDim.x);

        for (int index = partition.startIndex; index <= partition.endIndex; ++index) {
            auto const& particle = dataTO.particles[index];
            numberGen.adaptMaxId(particle.id);
        }
    }
}

__global__ void cudaClearDataTO(DataTO dataTO)
{
    *dataTO.numCells = 0;
    *dataTO.numParticles = 0;
    *dataTO.numAdditionalData = 0;
}

__global__ void cudaClearData(SimulationData data)
{
    data.objects.cellPointers.reset();
    data.objects.particlePointers.reset();
    data.objects.cells.reset();
    data.objects.particles.reset();
    data.objects.additionalData.reset();
}

__global__ void cudaSaveNumEntries(SimulationData data)
{
    data.objects.saveNumEntries();
}
