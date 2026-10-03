#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "TimerManager.h"
#include "Prototype01TerrainHazardActor.generated.h"

class UMaterialInstanceDynamic;
class UStaticMeshComponent;

/**
 * Minaccia dummy graybox: attraversa una corsia rettilinea fissa a velocita costante.
 * Riparte dallo stesso Actor riutilizzato (nessun accumulo) quando raggiunge la destinazione
 * o viene fermata da una cella Raised della griglia terreno.
 */
UCLASS()
class PROTOTYPE01_API APrototype01TerrainHazardActor : public AActor
{
	GENERATED_BODY()

public:
	APrototype01TerrainHazardActor();

	virtual void BeginPlay() override;
	virtual void Tick(float DeltaSeconds) override;

	/** Configura origine, direzione planare (normalizzata) e lunghezza della corsia; riavvia il ciclo dall'origine. */
	void ConfigureLane(const FVector& InStartLocation, const FVector& InLaneDirection, float InLaneLength);

protected:
	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Prototype01|Hazard")
	TObjectPtr<UStaticMeshComponent> HazardMesh;

	/** Velocita di attraversamento della corsia in unita al secondo. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Prototype01|Hazard", meta = (ClampMin = "10.0"))
	float MoveSpeed = 350.0f;

	/** Intervallo prima di ripartire dopo essere stata fermata o aver raggiunto la destinazione. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Prototype01|Hazard", meta = (ClampMin = "0.05"))
	float RestartDelay = 1.0f;

private:
	FVector LaneStartLocation = FVector::ZeroVector;
	FVector LaneDirection = FVector::ForwardVector;
	float LaneLength = 1000.0f;
	float TraveledDistance = 0.0f;
	bool bResting = false;

	FTimerHandle RestartTimerHandle;

	void ScheduleRestart();
	void RestartLane();
};
