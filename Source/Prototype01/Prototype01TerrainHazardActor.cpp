#include "Prototype01TerrainHazardActor.h"

#include "Components/StaticMeshComponent.h"
#include "Engine/StaticMesh.h"
#include "Materials/MaterialInstanceDynamic.h"
#include "Materials/MaterialInterface.h"
#include "UObject/ConstructorHelpers.h"

namespace
{
	const TCHAR* SphereMeshPath = TEXT("/Engine/BasicShapes/Sphere.Sphere");
	const TCHAR* BasicShapeMaterialPath = TEXT("/Engine/BasicShapes/BasicShapeMaterial.BasicShapeMaterial");
	const FName ColorParamName(TEXT("Color"));

	// Magenta acceso: distinto dal corpo arancione del personaggio e dai toni verde/blu/arancio del terreno.
	const FLinearColor HazardColor(0.95f, 0.05f, 0.85f);

	const float HazardMeshRadius = 45.0f;
}

APrototype01TerrainHazardActor::APrototype01TerrainHazardActor()
{
	PrimaryActorTick.bCanEverTick = true;

	HazardMesh = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("HazardMesh"));
	SetRootComponent(HazardMesh);
	HazardMesh->SetRelativeScale3D(FVector(HazardMeshRadius / 50.0f));
	HazardMesh->SetCastShadow(true);

	// Collide solo con la geometria terreno/arena (WorldStatic): ignora i Pawn per non spingere il giocatore.
	HazardMesh->SetCollisionEnabled(ECollisionEnabled::QueryOnly);
	HazardMesh->SetCollisionObjectType(ECC_Pawn);
	HazardMesh->SetCollisionResponseToAllChannels(ECR_Ignore);
	HazardMesh->SetCollisionResponseToChannel(ECC_WorldStatic, ECR_Block);

	static ConstructorHelpers::FObjectFinder<UStaticMesh> SphereMeshAsset(SphereMeshPath);
	static ConstructorHelpers::FObjectFinder<UMaterialInterface> BasicShapeMaterialAsset(BasicShapeMaterialPath);
	if (SphereMeshAsset.Succeeded())
	{
		HazardMesh->SetStaticMesh(SphereMeshAsset.Object);
	}
	if (BasicShapeMaterialAsset.Succeeded())
	{
		HazardMesh->SetMaterial(0, BasicShapeMaterialAsset.Object);
	}
}

void APrototype01TerrainHazardActor::BeginPlay()
{
	Super::BeginPlay();

	if (UMaterialInstanceDynamic* HazardMID = HazardMesh->CreateAndSetMaterialInstanceDynamic(0))
	{
		HazardMID->SetVectorParameterValue(ColorParamName, HazardColor);
	}

	if (LaneStartLocation.IsNearlyZero())
	{
		LaneStartLocation = GetActorLocation();
	}
}

void APrototype01TerrainHazardActor::Tick(float DeltaSeconds)
{
	Super::Tick(DeltaSeconds);

	if (bResting)
	{
		return;
	}

	const float StepDistance = MoveSpeed * DeltaSeconds;
	FHitResult Hit;
	AddActorWorldOffset(LaneDirection * StepDistance, true, &Hit);

	if (Hit.bBlockingHit)
	{
		UE_LOG(LogTemp, Log, TEXT("PROTOTYPE01_TERRAIN_HAZARD_BLOCKED"));
		ScheduleRestart();
		return;
	}

	TraveledDistance += StepDistance;
	if (TraveledDistance >= LaneLength)
	{
		UE_LOG(LogTemp, Log, TEXT("PROTOTYPE01_TERRAIN_HAZARD_REACHED"));
		ScheduleRestart();
	}
}

void APrototype01TerrainHazardActor::ConfigureLane(const FVector& InStartLocation, const FVector& InLaneDirection, float InLaneLength)
{
	LaneStartLocation = InStartLocation;
	LaneDirection = InLaneDirection.GetSafeNormal2D();
	if (LaneDirection.IsNearlyZero())
	{
		LaneDirection = FVector::ForwardVector;
	}
	LaneLength = FMath::Max(InLaneLength, 100.0f);

	TraveledDistance = 0.0f;
	bResting = false;
	GetWorldTimerManager().ClearTimer(RestartTimerHandle);
	SetActorLocation(LaneStartLocation, false);
}

void APrototype01TerrainHazardActor::ScheduleRestart()
{
	bResting = true;
	HazardMesh->SetVisibility(false);
	GetWorldTimerManager().SetTimer(RestartTimerHandle, this, &APrototype01TerrainHazardActor::RestartLane, FMath::Max(RestartDelay, 0.05f), false);
}

void APrototype01TerrainHazardActor::RestartLane()
{
	TraveledDistance = 0.0f;
	SetActorLocation(LaneStartLocation, false);
	HazardMesh->SetVisibility(true);
	bResting = false;
}
