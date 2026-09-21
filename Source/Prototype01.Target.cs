using UnrealBuildTool;
using System.Collections.Generic;

public class Prototype01Target : TargetRules
{
	public Prototype01Target(TargetInfo Target) : base(Target)
	{
		Type = TargetType.Game;
		DefaultBuildSettings = BuildSettingsVersion.V5;
		IncludeOrderVersion = EngineIncludeOrderVersion.Unreal5_6;

		ExtraModuleNames.Add("Prototype01");
	}
}
