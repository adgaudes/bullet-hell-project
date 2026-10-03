#include "Prototype01ArenaActor.h"

#include "Components/SceneComponent.h"
#include "Components/StaticMeshComponent.h"
#include "Components/DirectionalLightComponent.h"
#include "Components/SkyLightComponent.h"
#include "Components/SkyAtmosphereComponent.h"
#include "Engine/StaticMesh.h"
#include "Materials/MaterialInterface.h"
#include "Materials/MaterialInstanceDynamic.h"
#include "UObject/ConstructorHelpers.h"

namespace
{
	/** Percorso Engine del materiale a griglia usato per il pavimento; nessun asset di progetto richiesto. */
	const TCHAR* GridMaterialPath = TEXT("/Engine/EngineMaterials/WorldGridMaterial.WorldGridMaterial");
	/** Materiale Engine base per le istanze dinamiche colorate di pilastri e landmark. */
	const TCHAR* BasicShapeMaterialPath = TEXT("/Engine/BasicShapes/BasicShapeMaterial.BasicShapeMaterial");
	const TCHAR* CubeMeshPath = TEXT("/Engine/BasicShapes/Cube.Cube");
	/** Nome del parametro colore esposto da BasicShapeMaterial. */
	const FName ColorParamName(TEXT("Color"));
}

APrototype01ArenaActor::APrototype01ArenaActor()
{
	PrimaryActorTick.bCanEverTick = false;

	ArenaRoot = CreateDefaultSubobject<USceneComponent>(TEXT("ArenaRoot"));
	SetRootComponent(ArenaRoot);

	static ConstructorHelpers::FObjectFinder<UStaticMesh> CubeMeshAsset(CubeMeshPath);
	static ConstructorHelpers::FObjectFinder<UMaterialInterface> GridMaterialAsset(GridMaterialPath);
	static ConstructorHelpers::FObjectFinder<UMaterialInterface> BasicShapeMaterialAsset(BasicShapeMaterialPath);

	FloorMesh = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("FloorMesh"));
	FloorMesh->SetupAttachment(ArenaRoot);
	FloorMesh->SetMobility(EComponentMobility::Movable);
	FloorMesh->SetCollisionEnabled(ECollisionEnabled::QueryAndPhysics);
	FloorMesh->SetCollisionObjectType(ECC_WorldStatic);
	FloorMesh->SetCollisionResponseToAllChannels(ECR_Block);
	FloorMesh->SetCastShadow(true);
	if (CubeMeshAsset.Succeeded())
	{
		FloorMesh->SetStaticMesh(CubeMeshAsset.Object);
	}
	if (GridMaterialAsset.Succeeded())
	{
		FloorMesh->SetMaterial(0, GridMaterialAsset.Object);
	}
	// Il cubo Engine di base ha lato 100cm: la scala relativa converte i parametri in cm assoluti.
	FloorMesh->SetRelativeLocation(FVector::ZeroVector);
	FloorMesh->SetRelativeScale3D(FVector(FloorSize / 100.0f, FloorSize / 100.0f, FloorThickness / 100.0f));

	const float HalfFloor = FloorSize * 0.5f;
	const float CornerOffset = HalfFloor - PillarInsetFromEdge;
	const float PillarRelativeZ = (FloorThickness * 0.5f) + (PillarHeight * 0.5f);
	const FVector2D CornerLocalOffsets[4] =
	{
		FVector2D(CornerOffset, CornerOffset),
		FVector2D(-CornerOffset, CornerOffset),
		FVector2D(-CornerOffset, -CornerOffset),
		FVector2D(CornerOffset, -CornerOffset)
	};

	CornerPillars.Reserve(4);
	for (int32 Index = 0; Index < 4; ++Index)
	{
		const FName PillarName(*FString::Printf(TEXT("CornerPillar%d"), Index));
		UStaticMeshComponent* Pillar = CreateDefaultSubobject<UStaticMeshComponent>(PillarName);
		Pillar->SetupAttachment(ArenaRoot);
		Pillar->SetMobility(EComponentMobility::Movable);
		Pillar->SetCollisionEnabled(ECollisionEnabled::QueryAndPhysics);
		Pillar->SetCollisionObjectType(ECC_WorldStatic);
		Pillar->SetCollisionResponseToAllChannels(ECR_Block);
		Pillar->SetCastShadow(true);
		if (CubeMeshAsset.Succeeded())
		{
			Pillar->SetStaticMesh(CubeMeshAsset.Object);
		}
		if (BasicShapeMaterialAsset.Succeeded())
		{
			Pillar->SetMaterial(0, BasicShapeMaterialAsset.Object);
		}
		const FVector2D& Offset = CornerLocalOffsets[Index];
		Pillar->SetRelativeLocation(FVector(Offset.X, Offset.Y, PillarRelativeZ));
		Pillar->SetRelativeScale3D(FVector(PillarSize / 100.0f, PillarSize / 100.0f, PillarHeight / 100.0f));

		CornerPillars.Add(Pillar);
	}

	DirectionMarker = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("DirectionMarker"));
	DirectionMarker->SetupAttachment(ArenaRoot);
	DirectionMarker->SetMobility(EComponentMobility::Movable);
	DirectionMarker->SetCollisionEnabled(ECollisionEnabled::QueryAndPhysics);
	DirectionMarker->SetCollisionObjectType(ECC_WorldStatic);
	DirectionMarker->SetCollisionResponseToAllChannels(ECR_Block);
	DirectionMarker->SetCastShadow(true);
	if (CubeMeshAsset.Succeeded())
	{
		DirectionMarker->SetStaticMesh(CubeMeshAsset.Object);
	}
	if (BasicShapeMaterialAsset.Succeeded())
	{
		DirectionMarker->SetMaterial(0, BasicShapeMaterialAsset.Object);
	}
	// Landmark direzionale sul bordo +Y dell'arena (lato "nord"), utile come riferimento di orientamento.
	const float DirectionMarkerBaseSize = 200.0f;
	const float DirectionMarkerRelativeZ = (FloorThickness * 0.5f) + (DirectionMarkerHeight * 0.5f);
	DirectionMarker->SetRelativeLocation(FVector(0.0f, HalfFloor - PillarInsetFromEdge, DirectionMarkerRelativeZ));
	DirectionMarker->SetRelativeScale3D(FVector(DirectionMarkerBaseSize / 100.0f, DirectionMarkerBaseSize / 100.0f, DirectionMarkerHeight / 100.0f));

	SunLight = CreateDefaultSubobject<UDirectionalLightComponent>(TEXT("SunLight"));
	SunLight->SetupAttachment(ArenaRoot);
	SunLight->SetMobility(EComponentMobility::Movable);
	SunLight->SetRelativeRotation(FRotator(-45.0f, -30.0f, 0.0f));
	// Valore empirico da graybox: questo progetto non usa il range EV100 esteso per SkyAtmosphere,
	// quindi l'intensita resta compatibile con l'esposizione standard invece di usare unita fisiche in lux.
	// Tinta calda mantenuta per leggibilita e mood.
	SunLight->Intensity = 20.0f;
	SunLight->LightColor = FColor(255, 236, 209);
	SunLight->CastShadows = true;
	SunLight->SetAtmosphereSunLight(true);

	AmbientSkyLight = CreateDefaultSubobject<USkyLightComponent>(TEXT("AmbientSkyLight"));
	AmbientSkyLight->SetupAttachment(ArenaRoot);
	AmbientSkyLight->SetMobility(EComponentMobility::Movable);
	AmbientSkyLight->SourceType = ESkyLightSourceType::SLS_CapturedScene;
	AmbientSkyLight->bRealTimeCapture = true;
	AmbientSkyLight->Intensity = 1.5f;

	SkyAtmosphere = CreateDefaultSubobject<USkyAtmosphereComponent>(TEXT("SkyAtmosphere"));
	SkyAtmosphere->SetupAttachment(ArenaRoot);
	SkyAtmosphere->SetMobility(EComponentMobility::Movable);
}

void APrototype01ArenaActor::OnConstruction(const FTransform& Transform)
{
	Super::OnConstruction(Transform);
	ApplyVisualConfiguration();
}

void APrototype01ArenaActor::BeginPlay()
{
	Super::BeginPlay();
	ApplyVisualConfiguration();
}

void APrototype01ArenaActor::ApplyVisualConfiguration()
{
	const float HalfFloor = FloorSize * 0.5f;
	const float CornerOffset = HalfFloor - PillarInsetFromEdge;
	const float PillarRelativeZ = (FloorThickness * 0.5f) + (PillarHeight * 0.5f);
	const FVector2D CornerLocalOffsets[4] =
	{
		FVector2D(CornerOffset, CornerOffset),
		FVector2D(-CornerOffset, CornerOffset),
		FVector2D(-CornerOffset, -CornerOffset),
		FVector2D(CornerOffset, -CornerOffset)
	};

	if (FloorMesh)
	{
		FloorMesh->SetRelativeLocation(FVector::ZeroVector);
		FloorMesh->SetRelativeScale3D(FVector(FloorSize / 100.0f, FloorSize / 100.0f, FloorThickness / 100.0f));
	}

	const FLinearColor CornerPillarColors[4] =
	{
		FLinearColor(0.9f, 0.05f, 0.05f),
		FLinearColor(0.05f, 0.8f, 0.15f),
		FLinearColor(0.1f, 0.35f, 0.95f),
		FLinearColor(0.95f, 0.85f, 0.05f)
	};

	auto ApplyColor = [](UStaticMeshComponent* Component, const FLinearColor& Color)
	{
		if (!Component)
		{
			return;
		}

		UMaterialInstanceDynamic* MaterialInstance = Cast<UMaterialInstanceDynamic>(Component->GetMaterial(0));
		if (!MaterialInstance)
		{
			MaterialInstance = Component->CreateAndSetMaterialInstanceDynamic(0);
		}

		if (MaterialInstance)
		{
			MaterialInstance->SetVectorParameterValue(ColorParamName, Color);
		}
	};

	for (int32 Index = 0; Index < CornerPillars.Num(); ++Index)
	{
		if (UStaticMeshComponent* Pillar = CornerPillars[Index])
		{
			const FVector2D& Offset = CornerLocalOffsets[Index % 4];
			Pillar->SetRelativeLocation(FVector(Offset.X, Offset.Y, PillarRelativeZ));
			Pillar->SetRelativeScale3D(FVector(PillarSize / 100.0f, PillarSize / 100.0f, PillarHeight / 100.0f));
			ApplyColor(Pillar, CornerPillarColors[Index % 4]);
		}
	}

	if (DirectionMarker)
	{
		const float DirectionMarkerBaseSize = 200.0f;
		const float DirectionMarkerRelativeZ = (FloorThickness * 0.5f) + (DirectionMarkerHeight * 0.5f);
		DirectionMarker->SetRelativeLocation(FVector(0.0f, HalfFloor - PillarInsetFromEdge, DirectionMarkerRelativeZ));
		DirectionMarker->SetRelativeScale3D(FVector(DirectionMarkerBaseSize / 100.0f, DirectionMarkerBaseSize / 100.0f, DirectionMarkerHeight / 100.0f));
		ApplyColor(DirectionMarker, FLinearColor(0.85f, 0.1f, 0.85f));
	}

	if (SunLight)
	{
		SunLight->SetRelativeRotation(FRotator(-45.0f, -30.0f, 0.0f));
		SunLight->Intensity = 20.0f;
		SunLight->LightColor = FColor(255, 236, 209);
		SunLight->CastShadows = true;
		SunLight->SetAtmosphereSunLight(true);
	}

	if (AmbientSkyLight)
	{
		AmbientSkyLight->SourceType = ESkyLightSourceType::SLS_CapturedScene;
		AmbientSkyLight->bRealTimeCapture = true;
		AmbientSkyLight->Intensity = 1.5f;
	}

	if (SkyAtmosphere)
	{
		SkyAtmosphere->SetMobility(EComponentMobility::Movable);
	}
}

void APrototype01ArenaActor::AlignFloorTopToWorldLocation(const FVector& DesiredFloorTopLocation)
{
	FVector NewLocation = DesiredFloorTopLocation;
	NewLocation.Z -= (FloorThickness * 0.5f);
	SetActorLocation(NewLocation);
}
