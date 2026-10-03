#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "Prototype01ArenaActor.generated.h"

class USceneComponent;
class UStaticMeshComponent;
class UDirectionalLightComponent;
class USkyLightComponent;
class USkyAtmosphereComponent;

/**
 * Arena graybox riutilizzabile: pavimento con collisione, riferimenti geometrici
 * perimetrali/direzionali, Directional Light e illuminazione ambientale/sky.
 * Pensata per essere spawnata a runtime da una GameMode (es. SmokeTestGameMode)
 * nella posizione del pawn, cosi da restare valida indipendentemente dal PlayerStart della mappa.
 */
UCLASS()
class PROTOTYPE01_API APrototype01ArenaActor : public AActor
{
	GENERATED_BODY()

public:
	APrototype01ArenaActor();

	virtual void OnConstruction(const FTransform& Transform) override;
	virtual void BeginPlay() override;

	/**
	 * Riposiziona l'attore (mantenendo X/Y forniti) in modo che la superficie
	 * superiore del pavimento coincida con DesiredFloorTopLocation.Z.
	 * Permette a un chiamante (es. la GameMode) di far coincidere il pavimento
	 * con i piedi del pawn senza conoscere lo spessore interno del pavimento.
	 */
	void AlignFloorTopToWorldLocation(const FVector& DesiredFloorTopLocation);

protected:
	/** Applies geometry, materials, colors, and lighting consistently in Editor and PIE. */
	void ApplyVisualConfiguration();

	/** Radice non scalata della gerarchia; evita che la scala del pavimento si propaghi ai figli. */
	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Prototype01|Arena")
	TObjectPtr<USceneComponent> ArenaRoot;

	/** Pavimento collidibile dell'arena. */
	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Prototype01|Arena")
	TObjectPtr<UStaticMeshComponent> FloorMesh;

	/** Pilastri perimetrali collidibili, quattro angoli dell'arena. */
	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Prototype01|Arena")
	TArray<TObjectPtr<UStaticMeshComponent>> CornerPillars;

	/** Riferimento geometrico direzionale (landmark), posizionato su un lato dell'arena. */
	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Prototype01|Arena")
	TObjectPtr<UStaticMeshComponent> DirectionMarker;

	/** Sole/luce direzionale principale della scena. */
	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Prototype01|Lighting")
	TObjectPtr<UDirectionalLightComponent> SunLight;

	/** Luce ambientale che raccoglie il contributo del cielo/scena. */
	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Prototype01|Lighting")
	TObjectPtr<USkyLightComponent> AmbientSkyLight;

	/** Cielo fisico proceduralmente generato, nessun asset esterno richiesto. */
	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Prototype01|Lighting")
	TObjectPtr<USkyAtmosphereComponent> SkyAtmosphere;

	/** Lato del pavimento quadrato, in unita Unreal (cm). */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Prototype01|Arena")
	float FloorSize = 6000.0f;

	/** Spessore del pavimento. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Prototype01|Arena")
	float FloorThickness = 40.0f;

	/** Altezza dei pilastri perimetrali. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Prototype01|Arena")
	float PillarHeight = 500.0f;

	/** Lato/diametro approssimativo dei pilastri perimetrali. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Prototype01|Arena")
	float PillarSize = 150.0f;

	/** Distanza dei pilastri dal bordo del pavimento, lungo entrambi gli assi. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Prototype01|Arena")
	float PillarInsetFromEdge = 350.0f;

	/** Altezza del landmark direzionale. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Prototype01|Arena")
	float DirectionMarkerHeight = 700.0f;
};
