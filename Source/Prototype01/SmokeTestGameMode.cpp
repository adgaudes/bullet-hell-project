#include "SmokeTestGameMode.h"
#include "Prototype01Character.h"
#include "Prototype01ArenaActor.h"
#include "Prototype01TerrainGridActor.h"
#include "Prototype01TerrainHazardActor.h"

#include "Components/CapsuleComponent.h"
#include "Engine/World.h"
#include "EngineUtils.h"
#include "GameFramework/Character.h"
#include "GameFramework/Pawn.h"
#include "HAL/IConsoleManager.h"
#include "Kismet/GameplayStatics.h"

ASmokeTestGameMode::ASmokeTestGameMode()
{
	DefaultPawnClass = APrototype01Character::StaticClass();
}

void ASmokeTestGameMode::StartPlay()
{
	Super::StartPlay();

	UE_LOG(LogTemp, Log, TEXT("PROTOTYPE01_SMOKE_TEST_OK"));

	UWorld* World = GetWorld();
	if (!World)
	{
		return;
	}

	if (IConsoleVariable* EyeAdaptationQualityCVar = IConsoleManager::Get().FindConsoleVariable(TEXT("r.EyeAdaptationQuality")))
	{
		EyeAdaptationQualityCVar->Set(0, ECVF_SetByCode);
		UE_LOG(LogTemp, Log, TEXT("PROTOTYPE01_EXPOSURE_READY"));
	}
	else
	{
		UE_LOG(LogTemp, Warning, TEXT("PROTOTYPE01_EXPOSURE_CVAR_MISSING"));
	}

	// La mappa SmokeTest non definisce necessariamente un PlayerStart: l'arena di fallback
	// e la griglia terreno vengono posizionate in base al pawn effettivamente spawnato.
	FVector FloorTopTarget = FVector::ZeroVector;
	APrototype01Character* PrototypeCharacter = nullptr;
	if (APawn* PlayerPawn = UGameplayStatics::GetPlayerPawn(World, 0))
	{
		PrototypeCharacter = Cast<APrototype01Character>(PlayerPawn);
		FloorTopTarget = PlayerPawn->GetActorLocation();
		if (const ACharacter* PlayerCharacter = Cast<ACharacter>(PlayerPawn))
		{
			if (const UCapsuleComponent* Capsule = PlayerCharacter->GetCapsuleComponent())
			{
				FloorTopTarget.Z -= Capsule->GetScaledCapsuleHalfHeight();
			}
		}
	}

	bool bArenaReady = false;
	for (TActorIterator<APrototype01ArenaActor> ArenaIt(World); ArenaIt; ++ArenaIt)
	{
		UE_LOG(LogTemp, Log, TEXT("PROTOTYPE01_ARENA_PLACED_READY: %s"), *ArenaIt->GetActorNameOrLabel());
		bArenaReady = true;
		break;
	}

	if (!bArenaReady)
	{
		// Emergency fallback only: a correctly authored SmokeTest map contains a placed arena.
		FActorSpawnParameters SpawnParams;
		SpawnParams.SpawnCollisionHandlingOverride = ESpawnActorCollisionHandlingMethod::AlwaysSpawn;

		if (APrototype01ArenaActor* Arena = World->SpawnActor<APrototype01ArenaActor>(
			APrototype01ArenaActor::StaticClass(), FloorTopTarget, FRotator::ZeroRotator, SpawnParams))
		{
			Arena->AlignFloorTopToWorldLocation(FloorTopTarget);
			UE_LOG(LogTemp, Warning, TEXT("PROTOTYPE01_ARENA_FALLBACK_SPAWNED"));
		}
		else
		{
			UE_LOG(LogTemp, Error, TEXT("PROTOTYPE01_ARENA_FALLBACK_SPAWN_FAILED"));
		}
	}

	APrototype01TerrainGridActor* TerrainGrid = nullptr;
	for (TActorIterator<APrototype01TerrainGridActor> GridIt(World); GridIt; ++GridIt)
	{
		UE_LOG(LogTemp, Log, TEXT("PROTOTYPE01_TERRAIN_PLACED_READY: %s"), *GridIt->GetActorNameOrLabel());
		TerrainGrid = *GridIt;
		break;
	}

	if (!TerrainGrid)
	{
		FActorSpawnParameters TerrainSpawnParams;
		TerrainSpawnParams.SpawnCollisionHandlingOverride = ESpawnActorCollisionHandlingMethod::AlwaysSpawn;
		TerrainGrid = World->SpawnActor<APrototype01TerrainGridActor>(
			APrototype01TerrainGridActor::StaticClass(), FloorTopTarget, FRotator::ZeroRotator, TerrainSpawnParams);
		if (!TerrainGrid)
		{
			UE_LOG(LogTemp, Warning, TEXT("PROTOTYPE01_TERRAIN_SPAWN_FAILED"));
		}
	}

	if (TerrainGrid && PrototypeCharacter)
	{
		PrototypeCharacter->SetTerrainGrid(TerrainGrid);
	}
	else if (!PrototypeCharacter)
	{
		UE_LOG(LogTemp, Warning, TEXT("PROTOTYPE01_TERRAIN_CHARACTER_MISSING"));
	}

	if (TerrainGrid)
	{
		// Corsia fissa che attraversa l'intera griglia lungo l'asse locale X, oltre entrambi i bordi.
		const float LaneMargin = 260.0f;
		const float HalfLaneLength = TerrainGrid->GetGridWidthWorldExtent() * 0.5f + LaneMargin;
		const FVector GridOrigin = TerrainGrid->GetActorLocation();
		// Mantiene la sfera appena sopra il pavimento: a Z=0 lo sweep orizzontale
		// intercetterebbe l'arena invece delle sole celle Raised.
		const float LaneCenterHeight = 50.0f;
		const FVector LaneStart = GridOrigin + FVector(-HalfLaneLength, 0.0f, LaneCenterHeight);
		const FVector LaneDirection = FVector(1.0f, 0.0f, 0.0f);
		const float LaneLength = HalfLaneLength * 2.0f;

		APrototype01TerrainHazardActor* TerrainHazard = nullptr;
		for (TActorIterator<APrototype01TerrainHazardActor> HazardIt(World); HazardIt; ++HazardIt)
		{
			UE_LOG(LogTemp, Log, TEXT("PROTOTYPE01_TERRAIN_HAZARD_PLACED_READY: %s"), *HazardIt->GetActorNameOrLabel());
			TerrainHazard = *HazardIt;
			break;
		}

		if (!TerrainHazard)
		{
			FActorSpawnParameters HazardSpawnParams;
			HazardSpawnParams.SpawnCollisionHandlingOverride = ESpawnActorCollisionHandlingMethod::AlwaysSpawn;
			TerrainHazard = World->SpawnActor<APrototype01TerrainHazardActor>(
				APrototype01TerrainHazardActor::StaticClass(), LaneStart, FRotator::ZeroRotator, HazardSpawnParams);
			if (!TerrainHazard)
			{
				UE_LOG(LogTemp, Warning, TEXT("PROTOTYPE01_TERRAIN_HAZARD_SPAWN_FAILED"));
			}
		}

		if (TerrainHazard)
		{
			TerrainHazard->ConfigureLane(LaneStart, LaneDirection, LaneLength);
		}
	}

	UE_LOG(LogTemp, Log, TEXT("PROTOTYPE01_TERRAIN_SLICE_B_READY"));
}
