#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Character.h"
#include "InputActionValue.h"
#include "Prototype01Character.generated.h"

class UStaticMeshComponent;
class USpringArmComponent;
class UCameraComponent;
class UInputAction;
class UInputMappingContext;

/**
 * Personaggio graybox con camera isometrica fissa e movimento planare.
 * Orientamento indipendente dal movimento: stick destro (Enhanced Input) o mouse (deproiezione sul piano del personaggio).
 */
UCLASS()
class PROTOTYPE01_API APrototype01Character : public ACharacter
{
	GENERATED_BODY()

public:
	APrototype01Character();

	virtual void BeginPlay() override;
	virtual void Tick(float DeltaSeconds) override;
	virtual void SetupPlayerInputComponent(class UInputComponent* PlayerInputComponent) override;

protected:
	/** Mesh graybox del personaggio, senza collisione. */
	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Prototype01|Graybox")
	TObjectPtr<UStaticMeshComponent> GrayboxMesh;

	/** Braccio camera isometrico fisso. */
	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Prototype01|Camera")
	TObjectPtr<USpringArmComponent> CameraBoom;

	/** Camera di gioco. */
	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Prototype01|Camera")
	TObjectPtr<UCameraComponent> TopDownCamera;

	/** Velocita di movimento planare in unita al secondo. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Prototype01|Movement")
	float PlanarMoveSpeed = 600.0f;

	/** Lunghezza del braccio camera. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Prototype01|Camera")
	float CameraArmLength = 1500.0f;

	/** Inclinazione (pitch) della camera isometrica, in gradi. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Prototype01|Camera")
	float CameraPitchDegrees = -55.0f;

	/** Dead zone dello stick destro per attivare l'orientamento tramite gamepad. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Prototype01|Input")
	float AimStickDeadZone = 0.2f;

	/** Delta minimo del mouse per passare all'orientamento tramite mouse. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Prototype01|Input")
	float MouseAimDeltaThreshold = 0.1f;

private:
	/** Azione di movimento WASD / stick sinistro. */
	UPROPERTY(Transient)
	TObjectPtr<UInputAction> IA_Move;

	/** Azione di mira via stick destro. */
	UPROPERTY(Transient)
	TObjectPtr<UInputAction> IA_Aim;

	/** Mapping context di gameplay. */
	UPROPERTY(Transient)
	TObjectPtr<UInputMappingContext> IMC_Gameplay;

	enum class EAimControlMode : uint8
	{
		Gamepad,
		Mouse
	};

	EAimControlMode CurrentAimControlMode = EAimControlMode::Gamepad;

	FVector2D LastGamepadAimValue = FVector2D::ZeroVector;

	void SetupEnhancedInput();

	void HandleMoveTriggered(const FInputActionValue& Value);
	void HandleMoveCompleted(const FInputActionValue& Value);
	void HandleAimTriggered(const FInputActionValue& Value);
	void HandleAimCompleted(const FInputActionValue& Value);

	void UpdateMouseAimControlMode();
	void ApplyFacingRotation(float DeltaSeconds);
	bool ComputeMouseAimDirection(FVector& OutDirection) const;
};
