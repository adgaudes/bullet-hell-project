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
#include "InputCoreTypes.h"
#include "Engine/LocalPlayer.h"
#include "Materials/MaterialInterface.h"
#include "Materials/MaterialInstanceDynamic.h"
#include "UObject/ConstructorHelpers.h"

namespace
{
	/** Materiale Engine base per l'istanza dinamica colorata del personaggio; nessun asset di progetto richiesto. */
	const TCHAR* BasicShapeMaterialPath = TEXT("/Engine/BasicShapes/BasicShapeMaterial.BasicShapeMaterial");
	const FName ColorParamName(TEXT("Color"));
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
		GrayboxMesh->SetRelativeScale3D(FVector(0.9f, 0.45f, 0.9f));
	}
	if (BasicShapeMaterialAsset.Succeeded())
	{
		GrayboxMesh->SetMaterial(0, BasicShapeMaterialAsset.Object);
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
	Movement->GravityScale = 0.0f;
	Movement->bOrientRotationToMovement = false;
	Movement->MaxWalkSpeed = PlanarMoveSpeed;
	Movement->MaxFlySpeed = PlanarMoveSpeed;
	Movement->bConstrainToPlane = true;
	Movement->SetPlaneConstraintNormal(FVector::UpVector);
	Movement->bSnapToPlaneAtStart = true;
}

void APrototype01Character::BeginPlay()
{
	Super::BeginPlay();

	UE_LOG(LogTemp, Log, TEXT("PROTOTYPE01_CHARACTER_READY"));

	// Colore caldo/arancione ad alto contrasto: il personaggio deve restare leggibile sul pavimento a griglia grigio.
	if (UMaterialInstanceDynamic* GrayboxMID = GrayboxMesh->CreateAndSetMaterialInstanceDynamic(0))
	{
		GrayboxMID->SetVectorParameterValue(ColorParamName, FLinearColor(1.0f, 0.35f, 0.02f));
	}

	CameraBoom->TargetArmLength = CameraArmLength;
	CameraBoom->SetRelativeRotation(FRotator(CameraPitchDegrees, 0.0f, 0.0f));

	UCharacterMovementComponent* Movement = GetCharacterMovement();
	Movement->MaxWalkSpeed = PlanarMoveSpeed;
	Movement->MaxFlySpeed = PlanarMoveSpeed;
	Movement->SetMovementMode(MOVE_Flying);
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
}

void APrototype01Character::SetupEnhancedInput()
{
	if (!IA_Move)
	{
		IA_Move = NewObject<UInputAction>(this, TEXT("IA_Move"));
		IA_Move->ValueType = EInputActionValueType::Axis2D;

		IA_Aim = NewObject<UInputAction>(this, TEXT("IA_Aim"));
		IA_Aim->ValueType = EInputActionValueType::Axis2D;

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
	}
	else
	{
		UE_LOG(LogTemp, Error, TEXT("PROTOTYPE01_INPUT_COMPONENT_ERROR"));
	}
}

void APrototype01Character::HandleMoveTriggered(const FInputActionValue& Value)
{
	const FVector2D MoveValue = Value.Get<FVector2D>();

	AddMovementInput(FVector::ForwardVector, MoveValue.Y);
	AddMovementInput(FVector::RightVector, MoveValue.X);
}

void APrototype01Character::HandleMoveCompleted(const FInputActionValue& Value)
{
	(void)Value;
	// Nessuna azione: AddMovementInput non viene piu chiamato quando l'azione non e Triggered.
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
	(void)DeltaSeconds;
	FVector Direction = FVector::ZeroVector;
	bool bHasDirection = false;

	if (CurrentAimControlMode == EAimControlMode::Mouse)
	{
		bHasDirection = ComputeMouseAimDirection(Direction);
	}
	else if (!LastGamepadAimValue.IsNearlyZero())
	{
		Direction = FVector(LastGamepadAimValue.Y, LastGamepadAimValue.X, 0.0f);
		bHasDirection = true;
	}

	if (bHasDirection && !Direction.IsNearlyZero())
	{
		FRotator NewRotation = Direction.GetSafeNormal().Rotation();
		NewRotation.Pitch = 0.0f;
		NewRotation.Roll = 0.0f;
		SetActorRotation(NewRotation);
	}
}
