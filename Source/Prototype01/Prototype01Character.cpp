#include "Prototype01Character.h"

#include "Components/StaticMeshComponent.h"
#include "GameFramework/SpringArmComponent.h"
#include "GameFramework/CharacterMovementComponent.h"
#include "GameFramework/PlayerController.h"
#include "Camera/CameraComponent.h"
#include "EnhancedInputComponent.h"
#include "EnhancedInputSubsystems.h"
#include "InputMappingContext.h"
#include "InputAction.h"
#include "InputModifiers.h"
#include "InputTriggers.h"
#include "InputCoreTypes.h"
#include "Engine/LocalPlayer.h"
#include "Materials/MaterialInterface.h"
#include "Materials/MaterialInstanceDynamic.h"
#include "UObject/ConstructorHelpers.h"
#include "TimerManager.h"

namespace
{
	/** Materiale Engine base per l'istanza dinamica colorata del personaggio; nessun asset di progetto richiesto. */
	const TCHAR* BasicShapeMaterialPath = TEXT("/Engine/BasicShapes/BasicShapeMaterial.BasicShapeMaterial");
	const FName ColorParamName(TEXT("Color"));
	const FLinearColor GrayboxBodyColor(1.0f, 0.35f, 0.02f);
	const FLinearColor FacingIndicatorColor(0.0f, 0.8f, 1.0f);
	const FVector GrayboxBaseScale(0.9f, 0.45f, 0.9f);
}

APrototype01Character::APrototype01Character()
{
	PrimaryActorTick.bCanEverTick = true;

	GrayboxMesh = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("GrayboxMesh"));
	GrayboxMesh->SetupAttachment(RootComponent);
	GrayboxMesh->SetCollisionEnabled(ECollisionEnabled::NoCollision);
	GrayboxMesh->SetCollisionResponseToAllChannels(ECR_Ignore);
	GrayboxMesh->SetCastShadow(false);
	static ConstructorHelpers::FObjectFinder<UStaticMesh> GrayboxMeshAsset(TEXT("/Engine/BasicShapes/Cube.Cube"));
	static ConstructorHelpers::FObjectFinder<UMaterialInterface> BasicShapeMaterialAsset(BasicShapeMaterialPath);
	if (GrayboxMeshAsset.Succeeded())
	{
		GrayboxMesh->SetStaticMesh(GrayboxMeshAsset.Object);
		GrayboxMesh->SetRelativeScale3D(GrayboxBaseScale);
	}
	if (BasicShapeMaterialAsset.Succeeded())
	{
		GrayboxMesh->SetMaterial(0, BasicShapeMaterialAsset.Object);
	}

	// Indicatore graybox del Forward (+X): elimina l'ambiguita del corpo simmetrico, ancorato al bordo anteriore.
	FacingIndicatorMesh = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("FacingIndicatorMesh"));
	FacingIndicatorMesh->SetupAttachment(RootComponent);
	FacingIndicatorMesh->SetCollisionEnabled(ECollisionEnabled::NoCollision);
	FacingIndicatorMesh->SetCollisionResponseToAllChannels(ECR_Ignore);
	FacingIndicatorMesh->SetCastShadow(false);
	if (GrayboxMeshAsset.Succeeded())
	{
		FacingIndicatorMesh->SetStaticMesh(GrayboxMeshAsset.Object);
		FacingIndicatorMesh->SetRelativeLocation(FVector(60.0f, 0.0f, 25.0f));
		FacingIndicatorMesh->SetRelativeScale3D(FVector(0.35f, 0.35f, 0.35f));
	}
	if (BasicShapeMaterialAsset.Succeeded())
	{
		FacingIndicatorMesh->SetMaterial(0, BasicShapeMaterialAsset.Object);
	}

	CameraBoom = CreateDefaultSubobject<USpringArmComponent>(TEXT("CameraBoom"));
	CameraBoom->SetupAttachment(RootComponent);
	CameraBoom->TargetArmLength = CameraArmLength;
	CameraBoom->SetRelativeRotation(FRotator(CameraPitchDegrees, 0.0f, 0.0f));
	CameraBoom->SetUsingAbsoluteRotation(true);
	CameraBoom->bUsePawnControlRotation = false;
	CameraBoom->bInheritPitch = false;
	CameraBoom->bInheritYaw = false;
	CameraBoom->bInheritRoll = false;
	CameraBoom->bDoCollisionTest = false;

	TopDownCamera = CreateDefaultSubobject<UCameraComponent>(TEXT("TopDownCamera"));
	TopDownCamera->SetupAttachment(CameraBoom, USpringArmComponent::SocketName);
	TopDownCamera->bUsePawnControlRotation = false;

	bUseControllerRotationPitch = false;
	bUseControllerRotationYaw = false;
	bUseControllerRotationRoll = false;

	UCharacterMovementComponent* Movement = GetCharacterMovement();
	Movement->bOrientRotationToMovement = false;
	Movement->MaxWalkSpeed = PlanarMoveSpeed;
	Movement->MaxFlySpeed = PlanarMoveSpeed;
}

void APrototype01Character::BeginPlay()
{
	Super::BeginPlay();

	UE_LOG(LogTemp, Log, TEXT("PROTOTYPE01_CHARACTER_READY"));

	// Colore caldo/arancione ad alto contrasto: il personaggio deve restare leggibile sul pavimento a griglia grigio.
	GrayboxMID = GrayboxMesh->CreateAndSetMaterialInstanceDynamic(0);
	if (GrayboxMID)
	{
		GrayboxMID->SetVectorParameterValue(ColorParamName, GrayboxBodyColor);
	}

	// Indicatore Forward: colore bianco ad alto contrasto, distinto dal corpo.
	if (UMaterialInstanceDynamic* IndicatorMID = FacingIndicatorMesh->CreateAndSetMaterialInstanceDynamic(0))
	{
		IndicatorMID->SetVectorParameterValue(ColorParamName, FacingIndicatorColor);
	}

	CameraBoom->TargetArmLength = CameraArmLength;
	CameraBoom->SetRelativeRotation(FRotator(CameraPitchDegrees, 0.0f, 0.0f));

	UCharacterMovementComponent* Movement = GetCharacterMovement();
	Movement->MaxWalkSpeed = PlanarMoveSpeed;
	Movement->MaxFlySpeed = PlanarMoveSpeed;
	Movement->MaxAcceleration = MoveAcceleration;
	Movement->BrakingDecelerationWalking = MoveDeceleration;
	Movement->SetMovementMode(MOVE_Walking);
	if (APlayerController* PC = Cast<APlayerController>(GetController()))
	{
		PC->bShowMouseCursor = true;
	}
}

void APrototype01Character::Tick(float DeltaSeconds)
{
	Super::Tick(DeltaSeconds);

	UpdateMouseAimControlMode();
	ApplyFacingRotation(DeltaSeconds);

	if (bIsDashing)
	{
		GetCharacterMovement()->Velocity = DashDirection * DashSpeed;
	}
	else if (!CurrentMoveDirection.IsNearlyZero())
	{
		// Movimento planare tramite il percorso standard del CharacterMovement in MOVE_Walking.
		AddMovementInput(CurrentMoveDirection);
	}

	UpdateTerrainSpeedModifier();
	UpdateTerrainTarget();
}

void APrototype01Character::SetupEnhancedInput()
{
	if (!IA_Move)
	{
		IA_Move = NewObject<UInputAction>(this, TEXT("IA_Move"));
		IA_Move->ValueType = EInputActionValueType::Axis2D;
		IA_Move->Triggers.Add(NewObject<UInputTriggerDown>(IA_Move));

		IA_Aim = NewObject<UInputAction>(this, TEXT("IA_Aim"));
		IA_Aim->ValueType = EInputActionValueType::Axis2D;

		IA_Dash = NewObject<UInputAction>(this, TEXT("IA_Dash"));
		IA_Dash->ValueType = EInputActionValueType::Boolean;

		IA_TerrainTool = NewObject<UInputAction>(this, TEXT("IA_TerrainTool"));
		IA_TerrainTool->ValueType = EInputActionValueType::Boolean;

		IA_TerrainMode = NewObject<UInputAction>(this, TEXT("IA_TerrainMode"));
		IA_TerrainMode->ValueType = EInputActionValueType::Boolean;

		IMC_Gameplay = NewObject<UInputMappingContext>(this, TEXT("IMC_Gameplay"));

		UInputModifierSwizzleAxis* SwizzleW = NewObject<UInputModifierSwizzleAxis>(IMC_Gameplay);
		SwizzleW->Order = EInputAxisSwizzle::YXZ;
		FEnhancedActionKeyMapping& MapW = IMC_Gameplay->MapKey(IA_Move, EKeys::W);
		MapW.Modifiers.Add(SwizzleW);

		UInputModifierNegate* NegateS = NewObject<UInputModifierNegate>(IMC_Gameplay);
		UInputModifierSwizzleAxis* SwizzleS = NewObject<UInputModifierSwizzleAxis>(IMC_Gameplay);
		SwizzleS->Order = EInputAxisSwizzle::YXZ;
		FEnhancedActionKeyMapping& MapS = IMC_Gameplay->MapKey(IA_Move, EKeys::S);
		MapS.Modifiers.Add(NegateS);
		MapS.Modifiers.Add(SwizzleS);

		UInputModifierNegate* NegateA = NewObject<UInputModifierNegate>(IMC_Gameplay);
		FEnhancedActionKeyMapping& MapA = IMC_Gameplay->MapKey(IA_Move, EKeys::A);
		MapA.Modifiers.Add(NegateA);

		IMC_Gameplay->MapKey(IA_Move, EKeys::D);

		IMC_Gameplay->MapKey(IA_Move, EKeys::Gamepad_Left2D);
		IMC_Gameplay->MapKey(IA_Aim, EKeys::Gamepad_Right2D);

		IMC_Gameplay->MapKey(IA_Dash, EKeys::SpaceBar);
		IMC_Gameplay->MapKey(IA_Dash, EKeys::Gamepad_FaceButton_Bottom);

		IMC_Gameplay->MapKey(IA_TerrainTool, EKeys::LeftMouseButton);
		IMC_Gameplay->MapKey(IA_TerrainTool, EKeys::Gamepad_RightTrigger);
		IMC_Gameplay->MapKey(IA_TerrainMode, EKeys::RightMouseButton);
		IMC_Gameplay->MapKey(IA_TerrainMode, EKeys::Q);
		IMC_Gameplay->MapKey(IA_TerrainMode, EKeys::Gamepad_LeftShoulder);
	}

	if (APlayerController* PC = Cast<APlayerController>(GetController()))
	{
		if (UEnhancedInputLocalPlayerSubsystem* Subsystem = ULocalPlayer::GetSubsystem<UEnhancedInputLocalPlayerSubsystem>(PC->GetLocalPlayer()))
		{
			Subsystem->RemoveMappingContext(IMC_Gameplay);
			Subsystem->AddMappingContext(IMC_Gameplay, 0);
			UE_LOG(LogTemp, Log, TEXT("PROTOTYPE01_INPUT_READY"));
		}
	}
}

void APrototype01Character::SetupPlayerInputComponent(UInputComponent* PlayerInputComponent)
{
	Super::SetupPlayerInputComponent(PlayerInputComponent);
	SetupEnhancedInput();

	if (UEnhancedInputComponent* EnhancedInputComponent = Cast<UEnhancedInputComponent>(PlayerInputComponent))
	{
		EnhancedInputComponent->BindAction(IA_Move, ETriggerEvent::Triggered, this, &APrototype01Character::HandleMoveTriggered);
		EnhancedInputComponent->BindAction(IA_Move, ETriggerEvent::Completed, this, &APrototype01Character::HandleMoveCompleted);
		EnhancedInputComponent->BindAction(IA_Aim, ETriggerEvent::Triggered, this, &APrototype01Character::HandleAimTriggered);
		EnhancedInputComponent->BindAction(IA_Aim, ETriggerEvent::Completed, this, &APrototype01Character::HandleAimCompleted);
		EnhancedInputComponent->BindAction(IA_Dash, ETriggerEvent::Started, this, &APrototype01Character::HandleDashStarted);
		EnhancedInputComponent->BindAction(IA_TerrainTool, ETriggerEvent::Started, this, &APrototype01Character::HandleTerrainToolStarted);
		EnhancedInputComponent->BindAction(IA_TerrainMode, ETriggerEvent::Started, this, &APrototype01Character::HandleTerrainModeStarted);
	}
	else
	{
		UE_LOG(LogTemp, Error, TEXT("PROTOTYPE01_INPUT_COMPONENT_ERROR"));
	}
}

void APrototype01Character::HandleMoveTriggered(const FInputActionValue& Value)
{
	const FVector2D MoveValue = Value.Get<FVector2D>();

	const FVector WorldMoveDirection = (FVector::ForwardVector * MoveValue.Y) + (FVector::RightVector * MoveValue.X);
	if (!WorldMoveDirection.IsNearlyZero())
	{
		LastValidMoveDirection = WorldMoveDirection.GetSafeNormal();
	}

	if (bIsDashing)
	{
		return;
	}

	const float InputMagnitude = FMath::Clamp(MoveValue.Size(), 0.0f, 1.0f);
	CurrentMoveDirection = WorldMoveDirection.GetSafeNormal() * InputMagnitude;
}

void APrototype01Character::HandleMoveCompleted(const FInputActionValue& Value)
{
	(void)Value;
	CurrentMoveDirection = FVector::ZeroVector;
}

void APrototype01Character::HandleAimTriggered(const FInputActionValue& Value)
{
	const FVector2D AimValue = Value.Get<FVector2D>();
	LastGamepadAimValue = AimValue;

	if (AimValue.SizeSquared() > FMath::Square(AimStickDeadZone))
	{
		CurrentAimControlMode = EAimControlMode::Gamepad;
	}
}

void APrototype01Character::HandleAimCompleted(const FInputActionValue& Value)
{
	(void)Value;
	LastGamepadAimValue = FVector2D::ZeroVector;
}

void APrototype01Character::HandleDashStarted(const FInputActionValue& Value)
{
	(void)Value;
	StartDash();
}

void APrototype01Character::HandleTerrainToolStarted(const FInputActionValue& Value)
{
	(void)Value;
	if (TerrainGrid)
	{
		UpdateTerrainTarget();
		TerrainGrid->ApplyCommandAtWorldLocation(CurrentTerrainTarget, TerrainToolMode, this);
	}
}

void APrototype01Character::HandleTerrainModeStarted(const FInputActionValue& Value)
{
	(void)Value;
	TerrainToolMode = TerrainToolMode == EPrototypeTerrainToolMode::Dig
		? EPrototypeTerrainToolMode::Raise
		: EPrototypeTerrainToolMode::Dig;
	UE_LOG(LogTemp, Log, TEXT("PROTOTYPE01_TERRAIN_MODE %s"),
		TerrainToolMode == EPrototypeTerrainToolMode::Dig ? TEXT("Dig") : TEXT("Raise"));
	UpdateTerrainTarget();
}

void APrototype01Character::StartDash()
{
	if (bIsDashing || bDashOnCooldown)
	{
		return;
	}

	DashDirection = !LastValidMoveDirection.IsNearlyZero() ? LastValidMoveDirection : GetActorForwardVector();
	DashDirection.Z = 0.0f;
	DashDirection = DashDirection.GetSafeNormal();
	if (DashDirection.IsNearlyZero())
	{
		DashDirection = GetActorForwardVector();
	}

	bIsDashing = true;
	GetCharacterMovement()->Velocity = DashDirection * DashSpeed;

	if (GrayboxMID)
	{
		GrayboxMID->SetVectorParameterValue(ColorParamName, DashColor);
	}
	GrayboxMesh->SetRelativeScale3D(GrayboxBaseScale * DashScaleMultiplier);

	UE_LOG(LogTemp, Log, TEXT("PROTOTYPE01_DASH_STARTED"));

	EffectiveDashDuration = FMath::Max(DashDuration, 0.01f);
	GetWorldTimerManager().SetTimer(DashDurationTimerHandle, this, &APrototype01Character::EndDash, EffectiveDashDuration, false);
}

void APrototype01Character::EndDash()
{
	bIsDashing = false;
	bDashOnCooldown = true;

	GetCharacterMovement()->Velocity = FVector::ZeroVector;
	GrayboxMesh->SetRelativeScale3D(GrayboxBaseScale);

	if (GrayboxMID)
	{
		GrayboxMID->SetVectorParameterValue(ColorParamName, DashCooldownColor);
	}

	const float RemainingCooldown = FMath::Max(DashCooldown - EffectiveDashDuration, 0.0f);
	if (RemainingCooldown <= KINDA_SMALL_NUMBER)
	{
		EndDashCooldown();
	}
	else
	{
		GetWorldTimerManager().SetTimer(DashCooldownTimerHandle, this, &APrototype01Character::EndDashCooldown, RemainingCooldown, false);
	}
}

void APrototype01Character::EndDashCooldown()
{
	bDashOnCooldown = false;

	if (GrayboxMID)
	{
		GrayboxMID->SetVectorParameterValue(ColorParamName, GrayboxBodyColor);
	}

	UE_LOG(LogTemp, Log, TEXT("PROTOTYPE01_DASH_READY"));
}

void APrototype01Character::SetTerrainGrid(APrototype01TerrainGridActor* InTerrainGrid)
{
	TerrainGrid = InTerrainGrid;
	UpdateTerrainTarget();
	UE_LOG(LogTemp, Log, TEXT("PROTOTYPE01_TERRAIN_MODE Dig"));
}

void APrototype01Character::UpdateTerrainTarget()
{
	if (!TerrainGrid)
	{
		return;
	}

	FVector Forward = GetActorForwardVector();
	Forward.Z = 0.0f;
	if (!Forward.Normalize())
	{
		TerrainGrid->HidePreview();
		return;
	}

	CurrentTerrainTarget = GetActorLocation() + Forward * FMath::Max(TerrainToolRange, 100.0f);
	TerrainGrid->UpdatePreview(CurrentTerrainTarget, TerrainToolMode, this);
}

void APrototype01Character::UpdateTerrainSpeedModifier()
{
	float SpeedMultiplier = 1.0f;
	if (TerrainGrid)
	{
		bool bValidCell = false;
		const EPrototypeTerrainCellState State = TerrainGrid->GetCellStateAtWorldLocation(GetActorLocation(), bValidCell);
		if (bValidCell && State == EPrototypeTerrainCellState::Lowered)
		{
			SpeedMultiplier = 1.0f - FMath::Clamp(TerrainGrid->GetLoweredSpeedPenaltyPercent(), 0.0f, 0.95f);
		}
	}

	// Non altera mai PlanarMoveSpeed: ricalcola MaxWalkSpeed ogni tick a partire dalla base configurata.
	GetCharacterMovement()->MaxWalkSpeed = PlanarMoveSpeed * SpeedMultiplier;
}

void APrototype01Character::UpdateMouseAimControlMode()
{
	APlayerController* PC = Cast<APlayerController>(GetController());
	if (!PC)
	{
		return;
	}

	float DeltaX = 0.0f;
	float DeltaY = 0.0f;
	PC->GetInputMouseDelta(DeltaX, DeltaY);

	if (FMath::Square(DeltaX) + FMath::Square(DeltaY) > FMath::Square(MouseAimDeltaThreshold))
	{
		CurrentAimControlMode = EAimControlMode::Mouse;
	}
}

bool APrototype01Character::ComputeMouseAimDirection(FVector& OutDirection) const
{
	const APlayerController* PC = Cast<APlayerController>(GetController());
	if (!PC)
	{
		return false;
	}

	FVector WorldLocation;
	FVector WorldDirection;
	if (!PC->DeprojectMousePositionToWorld(WorldLocation, WorldDirection))
	{
		return false;
	}

	if (FMath::IsNearlyZero(WorldDirection.Z))
	{
		return false;
	}

	const float PlaneZ = GetActorLocation().Z;
	const float T = (PlaneZ - WorldLocation.Z) / WorldDirection.Z;
	if (T < 0.0f)
	{
		return false;
	}

	const FVector HitPoint = WorldLocation + WorldDirection * T;
	OutDirection = HitPoint - GetActorLocation();
	OutDirection.Z = 0.0f;

	return !OutDirection.IsNearlyZero();
}

void APrototype01Character::ApplyFacingRotation(float DeltaSeconds)
{
	FVector Direction = FVector::ZeroVector;
	bool bHasDirection = false;
	float InterpSpeed = GamepadAimRotationInterpSpeed;

	if (CurrentAimControlMode == EAimControlMode::Mouse)
	{
		bHasDirection = ComputeMouseAimDirection(Direction);
		InterpSpeed = MouseAimRotationInterpSpeed;
	}
	else
	{
		const float ClampedDeadZone = FMath::Clamp(AimStickDeadZone, 0.0f, 0.99f);
		const float AimMagnitude = LastGamepadAimValue.Size();
		if (AimMagnitude > ClampedDeadZone)
		{
			const float NormalizedMagnitude =
				(FMath::Min(AimMagnitude, 1.0f) - ClampedDeadZone) / (1.0f - ClampedDeadZone);
			const float AimResponse = FMath::Clamp(
				NormalizedMagnitude * FMath::Max(GamepadAimSensitivity, 0.0f), 0.0f, 1.0f);

			Direction = FVector(-LastGamepadAimValue.Y, LastGamepadAimValue.X, 0.0f);
			InterpSpeed = FMath::Max(GamepadAimRotationInterpSpeed, 0.0f) * AimResponse;
			bHasDirection = AimResponse > KINDA_SMALL_NUMBER;
		}
	}

	if (bHasDirection && !Direction.IsNearlyZero())
	{
		FRotator TargetRotation = Direction.GetSafeNormal().Rotation();
		TargetRotation.Pitch = 0.0f;
		TargetRotation.Roll = 0.0f;

		const FRotator NewRotation = FMath::RInterpTo(GetActorRotation(), TargetRotation, DeltaSeconds, InterpSpeed);
		SetActorRotation(NewRotation);
	}
}
