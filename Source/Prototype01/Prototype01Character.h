#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Character.h"
#include "InputActionValue.h"
#include "Prototype01TerrainGridActor.h"
#include "TimerManager.h"
#include "Prototype01Character.generated.h"

class UStaticMeshComponent;
class USpringArmComponent;
class UCameraComponent;
class UInputAction;
class UInputMappingContext;
class UMaterialInstanceDynamic;

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

	/** Collega la griglia terreno creata dalla GameMode senza ricerche globali per frame. */
	void SetTerrainGrid(APrototype01TerrainGridActor* InTerrainGrid);

protected:
	/** Mesh graybox del personaggio, senza collisione. */
	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Prototype01|Graybox")
	TObjectPtr<UStaticMeshComponent> GrayboxMesh;

	/** Indicatore graybox del Forward del personaggio (asse +X), senza collisione. */
	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Prototype01|Graybox")
	TObjectPtr<UStaticMeshComponent> FacingIndicatorMesh;

	/** Braccio camera isometrico fisso. */
	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Prototype01|Camera")
	TObjectPtr<USpringArmComponent> CameraBoom;

	/** Camera di gioco. */
	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Prototype01|Camera")
	TObjectPtr<UCameraComponent> TopDownCamera;

	/** Velocita massima di movimento planare in unita al secondo. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Prototype01|Movement")
	float PlanarMoveSpeed = 600.0f;

	/** Accelerazione applicata al CharacterMovement in modalita Flying. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Prototype01|Movement")
	float MoveAcceleration = 2048.0f;

	/** Decelerazione/frenata applicata al CharacterMovement in modalita Flying. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Prototype01|Movement")
	float MoveDeceleration = 2048.0f;

	/** Lunghezza del braccio camera. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Prototype01|Camera")
	float CameraArmLength = 1500.0f;

	/** Inclinazione (pitch) della camera isometrica, in gradi. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Prototype01|Camera")
	float CameraPitchDegrees = -55.0f;

	/** Dead zone dello stick destro per attivare l'orientamento tramite gamepad. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Prototype01|Input")
	float AimStickDeadZone = 0.2f;

	/** Sensibilita della mira gamepad: moltiplica la risposta della rotazione dopo la dead zone. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Prototype01|Input")
	float GamepadAimSensitivity = 1.0f;

	/** Rapidita di interpolazione della rotazione per la mira gamepad. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Prototype01|Input")
	float GamepadAimRotationInterpSpeed = 10.0f;

	/** Velocita di interpolazione della rotazione per la mira mouse; alta per restare reattiva. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Prototype01|Input")
	float MouseAimRotationInterpSpeed = 25.0f;

	/** Delta minimo del mouse per passare all'orientamento tramite mouse. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Prototype01|Input")
	float MouseAimDeltaThreshold = 0.1f;

	/** Velocita del dash in unita al secondo. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Prototype01|Dash")
	float DashSpeed = 3000.0f;

	/** Durata del dash in secondi. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Prototype01|Dash")
	float DashDuration = 0.18f;

	/** Cooldown del dash in secondi, misurato dall'attivazione. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Prototype01|Dash")
	float DashCooldown = 1.2f;

	/** Scala applicata al graybox durante il dash, come feedback visivo temporaneo. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Prototype01|Dash")
	float DashScaleMultiplier = 1.15f;

	/** Colore del graybox durante il dash. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Prototype01|Dash")
	FLinearColor DashColor = FLinearColor(0.1f, 0.9f, 1.0f);

	/** Colore del graybox durante il cooldown del dash. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Prototype01|Dash")
	FLinearColor DashCooldownColor = FLinearColor(0.4f, 0.4f, 0.4f);

	/** Distanza davanti al personaggio usata per selezionare la cella terreno. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Prototype01|Terrain", meta = (ClampMin = "100.0"))
	float TerrainToolRange = 480.0f;

private:
	/** Azione di movimento WASD / stick sinistro. */
	UPROPERTY(Transient)
	TObjectPtr<UInputAction> IA_Move;

	/** Azione di mira via stick destro. */
	UPROPERTY(Transient)
	TObjectPtr<UInputAction> IA_Aim;

	/** Azione semantica di dash (Space / Gamepad_FaceButton_Bottom). */
	UPROPERTY(Transient)
	TObjectPtr<UInputAction> IA_Dash;

	/** Applica la modalita terreno corrente alla cella bersaglio. */
	UPROPERTY(Transient)
	TObjectPtr<UInputAction> IA_TerrainTool;

	/** Alterna le modalita terreno Dig e Raise. */
	UPROPERTY(Transient)
	TObjectPtr<UInputAction> IA_TerrainMode;

	/** Mapping context di gameplay. */
	UPROPERTY(Transient)
	TObjectPtr<UInputMappingContext> IMC_Gameplay;

	/** Istanza dinamica di materiale del graybox, usata per il feedback dash/cooldown. */
	UPROPERTY(Transient)
	TObjectPtr<UMaterialInstanceDynamic> GrayboxMID;

	UPROPERTY(Transient)
	TObjectPtr<APrototype01TerrainGridActor> TerrainGrid;

	enum class EAimControlMode : uint8
	{
		Gamepad,
		Mouse
	};

	EAimControlMode CurrentAimControlMode = EAimControlMode::Gamepad;

	FVector2D LastGamepadAimValue = FVector2D::ZeroVector;

	/** Ultima direzione di movimento planare valida (normalizzata), usata come direzione di dash. */
	FVector LastValidMoveDirection = FVector::ZeroVector;

	bool bIsDashing = false;
	bool bDashOnCooldown = false;

	FVector DashDirection = FVector::ZeroVector;
	float EffectiveDashDuration = 0.0f;
	FVector CurrentTerrainTarget = FVector::ZeroVector;
	EPrototypeTerrainToolMode TerrainToolMode = EPrototypeTerrainToolMode::Dig;

	FTimerHandle DashDurationTimerHandle;
	FTimerHandle DashCooldownTimerHandle;

	void SetupEnhancedInput();

	void HandleMoveTriggered(const FInputActionValue& Value);
	void HandleMoveCompleted(const FInputActionValue& Value);
	void HandleAimTriggered(const FInputActionValue& Value);
	void HandleAimCompleted(const FInputActionValue& Value);
	void HandleDashStarted(const FInputActionValue& Value);
	void HandleTerrainToolStarted(const FInputActionValue& Value);
	void HandleTerrainModeStarted(const FInputActionValue& Value);

	void UpdateMouseAimControlMode();
	void ApplyFacingRotation(float DeltaSeconds);
	bool ComputeMouseAimDirection(FVector& OutDirection) const;

	void StartDash();
	void EndDash();
	void EndDashCooldown();
	void UpdateTerrainTarget();
};
