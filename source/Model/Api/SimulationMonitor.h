#pragma once

#include "Definitions.h"
#include "Descriptions.h"

struct MonitorData
{
	int numClusters = 0;
	int numCells = 0;
	int numParticles = 0;
	int numTokens = 0;
	double totalInternalEnergy = 0.0;
	double totalLinearKineticEnergy = 0.0;
	double totalRotationalKineticEnergy = 0.0;
};

class MODEL_EXPORT SimulationMonitor
	: public QObject
{
	Q_OBJECT
public:
	SimulationMonitor(QObject* parent = nullptr) : QObject(parent) {}
	virtual ~SimulationMonitor() = default;

	virtual void init(SimulationContext* context) = 0;

	virtual void requireData() = 0;
	Q_SIGNAL void dataReadyToRetrieve();
	virtual MonitorData const& retrieveData() = 0;
};
