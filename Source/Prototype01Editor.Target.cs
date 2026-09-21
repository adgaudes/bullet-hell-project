using UnrealBuildTool;
using System.Collections.Generic;

public class Prototype01EditorTarget : TargetRules
{
	public Prototype01EditorTarget(TargetInfo Target) : base(Target)
	{
		Type = TargetType.Editor;
		DefaultBuildSettings = BuildSettingsVersion.V5;
		IncludeOrderVersion = EngineIncludeOrderVersion.Unreal5_6;

		ExtraModuleNames.Add("Prototype01");
	}
}
