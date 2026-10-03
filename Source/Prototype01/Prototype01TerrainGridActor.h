#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "Prototype01TerrainGridActor.generated.h"

class UMaterialInstanceDynamic;
class UMaterialInterface;
class USceneComponent;
class UStaticMesh;
class UStaticMeshComponent;

UENUM(BlueprintType)
enum class EPrototypeTerrainCellState : uint8
{
	Lowered,
	Normal,
	Raised
};

UENUM(BlueprintType)
enum class EPrototypeTerrainToolMode : uint8
{
	Dig,
	Raise
};

/**
 * Griglia terreno graybox del primo slice. Lo stato logico e indipendente
 * dalle mesh runtime; solo le celle Raised hanno collisione.
 */
UCLASS()
class PROTOTYPE01_API APrototype01TerrainGridActor : public AActor
{
	GENERATED_BODY()

public:
	APrototype01TerrainGridActor();

	virtual void OnConstruction(const FTransform& Transform) override;
	virtual void BeginPlay() override;

	/** Aggiorna l'anteprima sulla cella contenente WorldTarget. InstigatorPawn e usato per il controllo anti-intrappolamento. */
	bool UpdatePreview(const FVector& WorldTarget, EPrototypeTerrainToolMode Mode, const AActor* InstigatorPawn = nullptr);

	/** Nasconde l'anteprima quando il bersaglio non e disponibile. */
	void HidePreview();

	/** Applica un singolo passo del comando alla cella bersaglio. InstigatorPawn e usato per il controllo anti-intrappolamento. */
	bool ApplyCommandAtWorldLocation(const FVector& WorldTarget, EPrototypeTerrainToolMode Mode, const AActor* InstigatorPawn = nullptr);

	/** Stato della cella nella posizione mondiale indicata; bOutValid=false se fuori griglia. */
	EPrototypeTerrainCellState GetCellStateAtWorldLocation(const FVector& WorldLocation, bool& bOutValid) const;

	/** Percentuale di velocita sottratta al personaggio quando si trova sopra una cella Lowered (0..0.95). */
	float GetLoweredSpeedPenaltyPercent() const { return LoweredSpeedPenaltyPercent; }

	/** Estensione mondiale della griglia lungo l'asse locale X (larghezza), in unita Unreal. */
	float GetGridWidthWorldExtent() const { return static_cast<float>(GridWidth) * CellSize; }

	/** Estensione mondiale della griglia lungo l'asse locale Y (profondita), in unita Unreal. */
	float GetGridDepthWorldExtent() const { return static_cast<float>(GridHeight) * CellSize; }

protected:
	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Prototype01|Terrain")
	TObjectPtr<USceneComponent> GridRoot;

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Prototype01|Terrain")
	TObjectPtr<UStaticMeshComponent> PreviewMesh;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Prototype01|Terrain", meta = (ClampMin = "1", ClampMax = "15"))
	int32 GridWidth = 7;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Prototype01|Terrain", meta = (ClampMin = "1", ClampMax = "15"))
	int32 GridHeight = 7;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Prototype01|Terrain", meta = (ClampMin = "100.0"))
	float CellSize = 240.0f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Prototype01|Terrain", meta = (ClampMin = "0.0"))
	float CellGap = 12.0f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Prototype01|Terrain|Presentation", meta = (ClampMin = "1.0"))
	float LoweredHeight = 4.0f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Prototype01|Terrain|Presentation", meta = (ClampMin = "1.0"))
	float NormalHeight = 12.0f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Prototype01|Terrain|Presentation", meta = (ClampMin = "1.0"))
	float RaisedHeight = 120.0f;

	/** Percentuale di velocita sottratta al personaggio sopra una cella Lowered (0 = nessun rallentamento, 0.95 = quasi fermo). */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Prototype01|Terrain|Gameplay", meta = (ClampMin = "0.0", ClampMax = "0.95"))
	float LoweredSpeedPenaltyPercent = 0.5f;

private:
	UPROPERTY(Transient)
	TArray<EPrototypeTerrainCellState> CellStates;

	UPROPERTY(Transient)
	TArray<TObjectPtr<UStaticMeshComponent>> CellMeshes;

	UPROPERTY(Transient)
	TArray<TObjectPtr<UMaterialInstanceDynamic>> CellMaterials;

	UPROPERTY(Transient)
	TObjectPtr<UMaterialInstanceDynamic> PreviewMaterial;

	UPROPERTY()
	TObjectPtr<UStaticMesh> CubeMesh;

	UPROPERTY()
	TObjectPtr<UMaterialInterface> BasicShapeMaterial;

	int32 ProtectedCellX = 0;
	int32 ProtectedCellY = 0;
	int32 PreviewCellX = INDEX_NONE;
	int32 PreviewCellY = INDEX_NONE;

	bool WorldToCell(const FVector& WorldLocation, int32& OutX, int32& OutY) const;
	bool IsCellCoordinateValid(int32 X, int32 Y) const;
	bool IsCellProtected(int32 X, int32 Y) const;
	bool CanApplyCommand(int32 X, int32 Y, EPrototypeTerrainToolMode Mode, const AActor* InstigatorPawn) const;
	bool WouldRaiseOverlapPawn(int32 X, int32 Y, const AActor* InstigatorPawn) const;
	int32 CellToIndex(int32 X, int32 Y) const;
	FVector GetCellRelativeLocation(int32 X, int32 Y, EPrototypeTerrainCellState State) const;
	float GetStateHeight(EPrototypeTerrainCellState State) const;
	void ClampGridProperties();
	void CreateRuntimeCells();
	void DestroyGeneratedCellComponents();
	void UpdateCellPresentation(int32 X, int32 Y);
};
