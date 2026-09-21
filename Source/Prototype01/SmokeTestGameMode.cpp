#include "SmokeTestGameMode.h"
#include "Prototype01Character.h"

ASmokeTestGameMode::ASmokeTestGameMode()
{
	DefaultPawnClass = APrototype01Character::StaticClass();
}

void ASmokeTestGameMode::StartPlay()
{
	Super::StartPlay();

	UE_LOG(LogTemp, Log, TEXT("PROTOTYPE01_SMOKE_TEST_OK"));
}
