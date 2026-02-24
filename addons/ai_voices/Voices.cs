#if TOOLS
using Godot;
using System;

[Tool]
public partial class Voices : EditorPlugin
{
	Control dock;
	
	public override void _EnterTree()
	{
		dock = (Control)GD.Load<PackedScene>("addons/ai_voices/Dock_aivoices.tscn").Instantiate();
		AddControlToDock(DockSlot.LeftUl, dock);
	}

	public override void _ExitTree()
	{
		RemoveControlFromDocks(dock);
		dock.Free();
	}
	
}
#endif
