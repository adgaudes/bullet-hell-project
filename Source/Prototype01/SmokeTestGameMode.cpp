#include "SmokeTestGameMode.h"
#include "Prototype01Character.h"
#include "Prototype01ArenaActor.h"
#include "Prototype01TerrainGridActor.h"

#include "Components/CapsuleComponent.h"
#include "Engine/World.h"
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

	// La mappa SmokeTest non definisce necessariamente un PlayerStart: l'arena viene
	// posizionata in base al pawn effettivamente spawnato, cosi il pavimento e sempre
	// sotto i suoi piedi indipendentemente dal punto di spawn della mappa.
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

	if (IConsoleVariable* EyeAdaptationQualityCVar = IConsoleManager::Get().FindConsoleVariable(TEXT("r.EyeAdaptationQuality")))
	{
		EyeAdaptationQualityCVar->Set(0, ECVF_SetByCode);
		UE_LOG(LogTemp, Log, TEXT("PROTOTYPE01_EXPOSURE_READY"));
	}
	else
	{
		UE_LOG(LogTemp, Warning, TEXT("PROTOTYPE01_EXPOSURE_CVAR_MISSING"));
	}

	FActorSpawnParameters SpawnParams;
	SpawnParams.SpawnCollisionHandlingOverride = ESpawnActorCollisionHandlingMethod::AlwaysSpawn;

	if (APrototype01ArenaActor* Arena = World->SpawnActor<APrototype01ArenaActor>(
		APrototype01ArenaActor::StaticClass(), FloorTopTarget, FRotator::ZeroRotator, SpawnParams))
	{
		Arena->AlignFloorTopToWorldLocation(FloorTopTarget);
		UE_LOG(LogTemp, Log, TEXT("PROTOTYPE01_ARENA_READY"));
	}
	else
	{
		UE_LOG(LogTemp, Warning, TEXT("PROTOTYPE01_ARENA_SPAWN_FAILED"));
	}

	if (APrototype01TerrainGridActor* TerrainGrid = World->SpawnActor<APrototype01TerrainGridActor>(
		APrototype01TerrainGridActor::StaticClass(), FloorTopTarget, FRotator::ZeroRotator, SpawnParams))
	{
		if (PrototypeCharacter)
		{
			PrototypeCharacter->SetTerrainGrid(TerrainGrid);
		}
		else
		{
			UE_LOG(LogTemp, Warning, TEXT("PROTOTYPE01_TERRAIN_CHARACTER_MISSING"));
		}
	}
	else
	{
		UE_LOG(LogTemp, Warning, TEXT("PROTOTYPE01_TERRAIN_SPAWN_FAILED"));
	}
}
