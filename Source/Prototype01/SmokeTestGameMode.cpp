#include "SmokeTestGameMode.h"

void ASmokeTestGameMode::StartPlay()
{
	Super::StartPlay();

	UE_LOG(LogTemp, Log, TEXT("PROTOTYPE01_SMOKE_TEST_OK"));
}
