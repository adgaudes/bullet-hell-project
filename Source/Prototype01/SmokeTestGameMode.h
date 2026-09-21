#pragma once

#include "CoreMinimal.h"
#include "GameFramework/GameModeBase.h"
#include "SmokeTestGameMode.generated.h"

UCLASS()
class PROTOTYPE01_API ASmokeTestGameMode : public AGameModeBase
{
	GENERATED_BODY()

public:
	virtual void StartPlay() override;
};
