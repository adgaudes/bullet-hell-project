#include "Prototype01TerrainGridActor.h"

#include "Components/SceneComponent.h"
#include "Components/StaticMeshComponent.h"
#include "Engine/StaticMesh.h"
#include "Materials/MaterialInstanceDynamic.h"
#include "Materials/MaterialInterface.h"
#include "UObject/ConstructorHelpers.h"

namespace
{
	const TCHAR* CubeMeshPath = TEXT("/Engine/BasicShapes/Cube.Cube");
	const TCHAR* BasicShapeMaterialPath = TEXT("/Engine/BasicShapes/BasicShapeMaterial.BasicShapeMaterial");
	const FName ColorParamName(TEXT("Color"));

	const FLinearColor NormalColor(0.34f, 0.48f, 0.20f);
	const FLinearColor LoweredColor(0.08f, 0.16f, 0.20f);
	const FLinearColor RaisedColor(0.64f, 0.28f, 0.08f);
	const FLinearColor ProtectedColor(0.42f, 0.12f, 0.48f);
	const FLinearColor DigPreviewColor(0.05f, 0.75f, 1.0f);
	const FLinearColor RaisePreviewColor(1.0f, 0.78f, 0.05f);
	const FLinearColor InvalidPreviewColor(1.0f, 0.03f, 0.03f);

	const FName CellComponentTag(TEXT("Prototype01TerrainCell"));

	const TCHAR* StateToString(EPrototypeTerrainCellState State)
	{
		switch (State)
		{
		case EPrototypeTerrainCellState::Lowered:
			return TEXT("Lowered");
		case EPrototypeTerrainCellState::Raised:
			return TEXT("Raised");
		default:
			return TEXT("Normal");
		}
	}
}

APrototype01TerrainGridActor::APrototype01TerrainGridActor()
{
	PrimaryActorTick.bCanEverTick = false;

	GridRoot = CreateDefaultSubobject<USceneComponent>(TEXT("GridRoot"));
	SetRootComponent(GridRoot);

	static ConstructorHelpers::FObjectFinder<UStaticMesh> CubeMeshAsset(CubeMeshPath);
	static ConstructorHelpers::FObjectFinder<UMaterialInterface> BasicShapeMaterialAsset(BasicShapeMaterialPath);
	CubeMesh = CubeMeshAsset.Object;
	BasicShapeMaterial = BasicShapeMaterialAsset.Object;

	PreviewMesh = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("PreviewMesh"));
	PreviewMesh->SetupAttachment(GridRoot);
	PreviewMesh->SetCollisionEnabled(ECollisionEnabled::NoCollision);
	PreviewMesh->SetCollisionResponseToAllChannels(ECR_Ignore);
	PreviewMesh->SetCastShadow(false);
	PreviewMesh->SetVisibility(false);
	if (CubeMesh)
	{
		PreviewMesh->SetStaticMesh(CubeMesh);
	}
	if (BasicShapeMaterial)
	{
		PreviewMesh->SetMaterial(0, BasicShapeMaterial);
	}
}

void APrototype01TerrainGridActor::OnConstruction(const FTransform& Transform)
{
	Super::OnConstruction(Transform);

	ClampGridProperties();
	CreateRuntimeCells();
}

void APrototype01TerrainGridActor::BeginPlay()
{
	Super::BeginPlay();

	// OnConstruction ha gia costruito la griglia per questa istanza (Editor e PIE condividono
	// lo stesso percorso); qui ricostruiamo solo se manca, senza duplicare le celle.
	const int32 ExpectedCellCount = GridWidth * GridHeight;
	if (CellMeshes.Num() != ExpectedCellCount || CellStates.Num() != ExpectedCellCount)
	{
		ClampGridProperties();
		CreateRuntimeCells();
	}

	if (BasicShapeMaterial && !PreviewMaterial)
	{
		PreviewMaterial = UMaterialInstanceDynamic::Create(BasicShapeMaterial, this);
		PreviewMesh->SetMaterial(0, PreviewMaterial);
	}

	UE_LOG(LogTemp, Log, TEXT("PROTOTYPE01_TERRAIN_GRID_READY Width=%d Height=%d"), GridWidth, GridHeight);
}

bool APrototype01TerrainGridActor::UpdatePreview(const FVector& WorldTarget, EPrototypeTerrainToolMode Mode, const AActor* InstigatorPawn)
{
	int32 X = INDEX_NONE;
	int32 Y = INDEX_NONE;
	if (!WorldToCell(WorldTarget, X, Y))
	{
		HidePreview();
		return false;
	}

	PreviewCellX = X;
	PreviewCellY = Y;
	const int32 Index = CellToIndex(X, Y);
	const EPrototypeTerrainCellState State = CellStates[Index];
	const bool bCanApply = CanApplyCommand(X, Y, Mode, InstigatorPawn);
	const FVector CellLocation = GetCellRelativeLocation(X, Y, State);
	const float PreviewSize = FMath::Max(CellSize - CellGap, 10.0f) * 0.72f;
	const float PreviewHeight = 5.0f;

	PreviewMesh->SetRelativeLocation(FVector(CellLocation.X, CellLocation.Y, GetStateHeight(State) + PreviewHeight * 0.5f + 2.0f));
	PreviewMesh->SetRelativeScale3D(FVector(PreviewSize / 100.0f, PreviewSize / 100.0f, PreviewHeight / 100.0f));
	PreviewMesh->SetVisibility(true);

	if (PreviewMaterial)
	{
		const FLinearColor Color = !bCanApply
			? InvalidPreviewColor
			: (Mode == EPrototypeTerrainToolMode::Dig ? DigPreviewColor : RaisePreviewColor);
		PreviewMaterial->SetVectorParameterValue(ColorParamName, Color);
	}

	return bCanApply;
}

void APrototype01TerrainGridActor::HidePreview()
{
	PreviewCellX = INDEX_NONE;
	PreviewCellY = INDEX_NONE;
	PreviewMesh->SetVisibility(false);
}

bool APrototype01TerrainGridActor::ApplyCommandAtWorldLocation(const FVector& WorldTarget, EPrototypeTerrainToolMode Mode, const AActor* InstigatorPawn)
{
	int32 X = INDEX_NONE;
	int32 Y = INDEX_NONE;
	const bool bValidCoordinate = WorldToCell(WorldTarget, X, Y);
	if (!bValidCoordinate || !CanApplyCommand(X, Y, Mode, InstigatorPawn))
	{
		const bool bOccupiedRejection = bValidCoordinate && Mode == EPrototypeTerrainToolMode::Raise
			&& !IsCellProtected(X, Y) && CellStates[CellToIndex(X, Y)] != EPrototypeTerrainCellState::Raised
			&& WouldRaiseOverlapPawn(X, Y, InstigatorPawn);
		if (bOccupiedRejection)
		{
			UE_LOG(LogTemp, Log, TEXT("PROTOTYPE01_TERRAIN_RAISE_OCCUPIED_REJECTED X=%d Y=%d"), X, Y);
		}
		else
		{
			UE_LOG(LogTemp, Log, TEXT("PROTOTYPE01_TERRAIN_REJECTED X=%d Y=%d"), X, Y);
		}
		return false;
	}

	const int32 Index = CellToIndex(X, Y);
	EPrototypeTerrainCellState& State = CellStates[Index];
	if (Mode == EPrototypeTerrainToolMode::Dig)
	{
		State = State == EPrototypeTerrainCellState::Raised
			? EPrototypeTerrainCellState::Normal
			: EPrototypeTerrainCellState::Lowered;
	}
	else
	{
		State = State == EPrototypeTerrainCellState::Lowered
			? EPrototypeTerrainCellState::Normal
			: EPrototypeTerrainCellState::Raised;
	}

	UpdateCellPresentation(X, Y);
	UpdatePreview(WorldTarget, Mode, InstigatorPawn);
	UE_LOG(LogTemp, Log, TEXT("PROTOTYPE01_TERRAIN_CHANGED X=%d Y=%d State=%s"), X, Y, StateToString(State));
	return true;
}

EPrototypeTerrainCellState APrototype01TerrainGridActor::GetCellStateAtWorldLocation(const FVector& WorldLocation, bool& bOutValid) const
{
	int32 X = INDEX_NONE;
	int32 Y = INDEX_NONE;
	bOutValid = WorldToCell(WorldLocation, X, Y);
	return bOutValid ? CellStates[CellToIndex(X, Y)] : EPrototypeTerrainCellState::Normal;
}

bool APrototype01TerrainGridActor::WorldToCell(const FVector& WorldLocation, int32& OutX, int32& OutY) const
{
	const FVector LocalLocation = GetActorTransform().InverseTransformPosition(WorldLocation);
	const float HalfWidth = static_cast<float>(GridWidth - 1) * 0.5f;
	const float HalfHeight = static_cast<float>(GridHeight - 1) * 0.5f;
	OutX = FMath::RoundToInt(LocalLocation.X / CellSize + HalfWidth);
	OutY = FMath::RoundToInt(LocalLocation.Y / CellSize + HalfHeight);
	return IsCellCoordinateValid(OutX, OutY);
}

bool APrototype01TerrainGridActor::IsCellCoordinateValid(int32 X, int32 Y) const
{
	return X >= 0 && X < GridWidth && Y >= 0 && Y < GridHeight;
}

bool APrototype01TerrainGridActor::IsCellProtected(int32 X, int32 Y) const
{
	return X == ProtectedCellX && Y == ProtectedCellY;
}

bool APrototype01TerrainGridActor::CanApplyCommand(int32 X, int32 Y, EPrototypeTerrainToolMode Mode, const AActor* InstigatorPawn) const
{
	if (!IsCellCoordinateValid(X, Y) || IsCellProtected(X, Y))
	{
		return false;
	}

	const EPrototypeTerrainCellState State = CellStates[CellToIndex(X, Y)];
	if (Mode == EPrototypeTerrainToolMode::Dig)
	{
		return State != EPrototypeTerrainCellState::Lowered;
	}

	if (State == EPrototypeTerrainCellState::Raised)
	{
		return false;
	}

	// Impedisce di rialzare una cella se la nuova geometria intersecherebbe il Pawn richiedente.
	return !WouldRaiseOverlapPawn(X, Y, InstigatorPawn);
}

bool APrototype01TerrainGridActor::WouldRaiseOverlapPawn(int32 X, int32 Y, const AActor* InstigatorPawn) const
{
	if (!InstigatorPawn)
	{
		return false;
	}

	const float CellVisualSize = FMath::Max(CellSize - CellGap, 10.0f);
	const float StateHeight = GetStateHeight(EPrototypeTerrainCellState::Raised);
	const FVector RelativeCenter = GetCellRelativeLocation(X, Y, EPrototypeTerrainCellState::Raised);
	const FVector HalfExtents(CellVisualSize * 0.5f, CellVisualSize * 0.5f, StateHeight * 0.5f);
	const FBox LocalBox(RelativeCenter - HalfExtents, RelativeCenter + HalfExtents);
	const FBox WorldBox = LocalBox.TransformBy(GetActorTransform());

	FVector PawnOrigin = FVector::ZeroVector;
	FVector PawnExtent = FVector::ZeroVector;
	// Considera solo i componenti collidenti: camera e spring arm renderebbero
	// altrimenti il bounding box molto piu grande del corpo del Pawn.
	InstigatorPawn->GetActorBounds(true, PawnOrigin, PawnExtent);
	const FBox PawnBox(PawnOrigin - PawnExtent, PawnOrigin + PawnExtent);

	return WorldBox.Intersect(PawnBox);
}

int32 APrototype01TerrainGridActor::CellToIndex(int32 X, int32 Y) const
{
	return Y * GridWidth + X;
}

FVector APrototype01TerrainGridActor::GetCellRelativeLocation(int32 X, int32 Y, EPrototypeTerrainCellState State) const
{
	const float HalfWidth = static_cast<float>(GridWidth - 1) * 0.5f;
	const float HalfHeight = static_cast<float>(GridHeight - 1) * 0.5f;
	return FVector(
		(static_cast<float>(X) - HalfWidth) * CellSize,
		(static_cast<float>(Y) - HalfHeight) * CellSize,
		GetStateHeight(State) * 0.5f);
}

float APrototype01TerrainGridActor::GetStateHeight(EPrototypeTerrainCellState State) const
{
	switch (State)
	{
	case EPrototypeTerrainCellState::Lowered:
		return LoweredHeight;
	case EPrototypeTerrainCellState::Raised:
		return RaisedHeight;
	default:
		return NormalHeight;
	}
}

void APrototype01TerrainGridActor::ClampGridProperties()
{
	GridWidth = FMath::Clamp(GridWidth, 1, 15);
	GridHeight = FMath::Clamp(GridHeight, 1, 15);
	if ((GridWidth % 2) == 0)
	{
		--GridWidth;
	}
	if ((GridHeight % 2) == 0)
	{
		--GridHeight;
	}
	CellSize = FMath::Max(CellSize, 100.0f);
	CellGap = FMath::Clamp(CellGap, 0.0f, CellSize * 0.4f);
	LoweredHeight = FMath::Max(LoweredHeight, 1.0f);
	NormalHeight = FMath::Max(NormalHeight, LoweredHeight);
	RaisedHeight = FMath::Max(RaisedHeight, NormalHeight);
}

void APrototype01TerrainGridActor::CreateRuntimeCells()
{
	// Ricostruzione idempotente: rimuove sempre prima le celle generate in precedenza
	// (tag Prototype01TerrainCell), cosi Editor rerun-construction, modifica proprieta,
	// caricamento mappa e ingresso in PIE non producono mai componenti duplicati.
	DestroyGeneratedCellComponents();

	const int32 CellCount = GridWidth * GridHeight;
	if (CellStates.Num() != CellCount)
	{
		// Dimensioni cambiate: reset dello stato logico. A parita di dimensioni lo stato
		// Dig/Raise corrente viene invece conservato attraverso la ricostruzione.
		CellStates.Init(EPrototypeTerrainCellState::Normal, CellCount);
	}
	CellMeshes.Reserve(CellCount);
	CellMaterials.Reserve(CellCount);

	for (int32 Y = 0; Y < GridHeight; ++Y)
	{
		for (int32 X = 0; X < GridWidth; ++X)
		{
			const int32 Index = CellToIndex(X, Y);
			const FName ComponentName = MakeUniqueObjectName(this, UStaticMeshComponent::StaticClass(), *FString::Printf(TEXT("TerrainCell_%d_%d"), X, Y));
			UStaticMeshComponent* CellMesh = NewObject<UStaticMeshComponent>(this, ComponentName);
			CellMesh->SetupAttachment(GridRoot);
			CellMesh->SetCollisionEnabled(ECollisionEnabled::NoCollision);
			CellMesh->SetCollisionResponseToAllChannels(ECR_Ignore);
			CellMesh->SetCastShadow(true);
			CellMesh->ComponentTags.Add(CellComponentTag);
			if (CubeMesh)
			{
				CellMesh->SetStaticMesh(CubeMesh);
			}
			AddInstanceComponent(CellMesh);
			CellMesh->RegisterComponent();
			CellMeshes.Add(CellMesh);

			UMaterialInstanceDynamic* CellMaterial = BasicShapeMaterial
				? UMaterialInstanceDynamic::Create(BasicShapeMaterial, this)
				: nullptr;
			if (CellMaterial)
			{
				CellMesh->SetMaterial(0, CellMaterial);
			}
			CellMaterials.Add(CellMaterial);
			UpdateCellPresentation(X, Y);
		}
	}
}

void APrototype01TerrainGridActor::DestroyGeneratedCellComponents()
{
	for (UActorComponent* Component : GetComponentsByTag(UStaticMeshComponent::StaticClass(), CellComponentTag))
	{
		if (Component)
		{
			Component->DestroyComponent();
		}
	}

	CellMeshes.Reset();
	CellMaterials.Reset();
}

void APrototype01TerrainGridActor::UpdateCellPresentation(int32 X, int32 Y)
{
	if (!IsCellCoordinateValid(X, Y))
	{
		return;
	}

	const int32 Index = CellToIndex(X, Y);
	if (!CellMeshes.IsValidIndex(Index) || !CellMeshes[Index])
	{
		return;
	}

	const EPrototypeTerrainCellState State = CellStates[Index];
	const float CellVisualSize = FMath::Max(CellSize - CellGap, 10.0f);
	const float StateHeight = GetStateHeight(State);
	CellMeshes[Index]->SetRelativeLocation(GetCellRelativeLocation(X, Y, State));
	CellMeshes[Index]->SetRelativeScale3D(FVector(CellVisualSize / 100.0f, CellVisualSize / 100.0f, StateHeight / 100.0f));

	// Collisione coerente con la geometria visibile: solo Raised blocca; Normal/Lowered restano attraversabili.
	if (State == EPrototypeTerrainCellState::Raised)
	{
		CellMeshes[Index]->SetCollisionEnabled(ECollisionEnabled::QueryAndPhysics);
		CellMeshes[Index]->SetCollisionObjectType(ECC_WorldStatic);
		CellMeshes[Index]->SetCollisionResponseToAllChannels(ECR_Block);
	}
	else
	{
		CellMeshes[Index]->SetCollisionEnabled(ECollisionEnabled::NoCollision);
		CellMeshes[Index]->SetCollisionResponseToAllChannels(ECR_Ignore);
	}

	if (CellMaterials.IsValidIndex(Index) && CellMaterials[Index])
	{
		FLinearColor Color = NormalColor;
		if (IsCellProtected(X, Y))
		{
			Color = ProtectedColor;
		}
		else if (State == EPrototypeTerrainCellState::Lowered)
		{
			Color = LoweredColor;
		}
		else if (State == EPrototypeTerrainCellState::Raised)
		{
			Color = RaisedColor;
		}
		CellMaterials[Index]->SetVectorParameterValue(ColorParamName, Color);
	}
}
