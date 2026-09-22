using UnrealBuildTool;
using System.Collections.Generic;

public class Prototype01Target : TargetRules
{
	public Prototype01Target(TargetInfo Target) : base(Target)
	{
		Type = TargetType.Game;
		DefaultBuildSettings = BuildSettingsVersion.V7;
		IncludeOrderVersion = EngineIncludeOrderVersion.Unreal5_8;
		WindowsPlatform.Compiler = WindowsCompiler.VisualStudio2026;
		WindowsPlatform.CompilerVersion = "14.51.36231";

		ExtraModuleNames.Add("Prototype01");
	}
}
