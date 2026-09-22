using UnrealBuildTool;
using System.Collections.Generic;

public class Prototype01EditorTarget : TargetRules
{
	public Prototype01EditorTarget(TargetInfo Target) : base(Target)
	{
		Type = TargetType.Editor;
		DefaultBuildSettings = BuildSettingsVersion.V7;
		IncludeOrderVersion = EngineIncludeOrderVersion.Unreal5_8;
		WindowsPlatform.Compiler = WindowsCompiler.VisualStudio2026;
		WindowsPlatform.CompilerVersion = "14.51.36231";

		ExtraModuleNames.Add("Prototype01");
	}
}
