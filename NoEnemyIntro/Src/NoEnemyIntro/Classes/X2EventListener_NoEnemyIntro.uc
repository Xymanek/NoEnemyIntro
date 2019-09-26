class X2EventListener_NoEnemyIntro extends X2EventListener config(NoEnemyIntro);

var config array<name> WhitelistCharaters;

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> Templates;

	Templates.AddItem(CreateNoEnemyIntroListeners());

	return Templates;
}

static function NEI_CHEventListenerTemplate CreateNoEnemyIntroListeners()
{
	local NEI_CHEventListenerTemplate Template;

	`CREATE_X2TEMPLATE(class'NEI_CHEventListenerTemplate', Template, 'NoEnemyIntro');
	Template.AddCHEvent('EnemyGroupSighted', EnemyGroupSighted, ELD_Immediate);
	Template.AddCHEvent('ScamperBegin', ScamperBegin, ELD_Immediate);
	Template.RegisterInTactical = true;

	return Template;
}

static protected function EventListenerReturn EnemyGroupSighted (Object EventData, Object EventSource, XComGameState GameState, Name EventID, Object CallbackData)
{
	local XComGameStateContext_ChangeContainer ChangeContainer;

	// If it's not XComGameStateContext_ChangeContainer then it's a reveal
	// Do not handle it here, It's handled in ScamperBegin listener
	ChangeContainer = XComGameStateContext_ChangeContainer(GameState.GetContext());
	if (ChangeContainer == none) return ELR_NoInterrupt;

	if (IsWhitelisted(XComGameState_AIGroup(EventData))) return ELR_NoInterrupt;

	if (ChangeContainer.BuildVisualizationFn != none)
	{
		ChangeContainer.BuildVisualizationFn = BuildVisualizationForFirstSightingOfEnemyGroup;
	}

	return ELR_NoInterrupt;
}

// Copy paste of the vanilla version, but with all the "First seen VO"-related code removed
static protected function BuildVisualizationForFirstSightingOfEnemyGroup (XComGameState VisualizeGameState)
{
	local VisualizationActionMetadata ActionMetadata, EmptyMetadata;
	local XComGameStateHistory History;
	local XComGameState_Unit UnitState, GroupLeaderUnitState, GroupUnitState;
	local X2Action_PlayEffect EffectAction;
	local XComGameState_AIGroup AIGroupState;
	local X2Action_UpdateUI UpdateUIAction;
	local X2Action_PlaySoundAndFlyOver SoundAndFlyOver;
	local bool bPlayedVO;
	local int Index;
	local X2Action_Delay DelayAction;
	local XComGameStateContext Context;
	local TTile TileLocation;

	Context = VisualizeGameState.GetContext();
	History = `XCOMHISTORY;

	foreach VisualizeGameState.IterateByClassType(class'XComGameState_AIGroup', AIGroupState)
	{
		UnitState = XComGameState_Unit(History.GetGameStateForObjectID(AIGroupState.SightedByUnitID));

		ActionMetadata = EmptyMetadata;

		ActionMetadata.StateObject_OldState = UnitState;
		ActionMetadata.StateObject_NewState = UnitState;

		SoundAndFlyOver = X2Action_PlaySoundAndFlyOver(class'X2Action_PlaySoundAndFlyOver'.static.AddToVisualizationTree(ActionMetadata, Context, false, ActionMetadata.LastActionAdded));

		// always center the camera on the enemy group for a few seconds and clear the FOW
		EffectAction = X2Action_PlayEffect(class'X2Action_PlayEffect'.static.AddToVisualizationTree(ActionMetadata, Context, false, ActionMetadata.LastActionAdded));
		EffectAction.CenterCameraOnEffectDuration = 1.0;
		EffectAction.RevealFOWRadius = class'XComWorldData'.const.WORLD_StepSize * 5.0f;
		EffectAction.FOWViewerObjectID = AIGroupState.m_arrMembers[0].ObjectID; //Setting this to be a unit makes it possible for the FOW viewer to reveal units
		TileLocation = XComGameState_Unit(History.GetGameStateForObjectID(AIGroupState.m_arrMembers[0].ObjectID)).TileLocation;
		EffectAction.EffectLocation = `XWORLD.GetPositionFromTileCoordinates(TileLocation); //Use the first unit in the group for the first sighted.
		EffectAction.bWaitForCameraArrival = true;
		EffectAction.bWaitForCameraCompletion = false;

		UpdateUIAction = X2Action_UpdateUI(class'X2Action_UpdateUI'.static.AddToVisualizationTree(ActionMetadata, Context, false, ActionMetadata.LastActionAdded));
		UpdateUIAction.UpdateType = EUIUT_Pathing_Concealment;

		GroupLeaderUnitState = XComGameState_Unit(History.GetGameStateForObjectID(AIGroupState.m_arrMembers[0].ObjectID));
		if( !bPlayedVO && !GroupLeaderUnitState.GetMyTemplate().bIsTurret )
		{
			if( GroupLeaderUnitState.IsAdvent() )
			{
				bPlayedVO = true;
				if( UnitState.IsConcealed() )
				{
					SoundAndFlyOver.SetSoundAndFlyOverParameters(None, "", 'EnemyPatrolSpotted', eColor_Good);
				}
				else
				{
					SoundAndFlyOver.SetSoundAndFlyOverParameters(None, "", 'ADVENTsighting', eColor_Good);
				}
			}
			else
			{
				// Iterate through other units to see if there are advent units
				for( Index = 1; Index < AIGroupState.m_arrMembers.Length; Index++ )
				{
					GroupUnitState = XComGameState_Unit(History.GetGameStateForObjectID(AIGroupState.m_arrMembers[Index].ObjectID));
					if( !bPlayedVO && GroupUnitState.IsAdvent() )
					{
						bPlayedVO = true;
						if( UnitState.IsConcealed() )
						{
							SoundAndFlyOver.SetSoundAndFlyOverParameters(None, "", 'EnemyPatrolSpotted', eColor_Good);
						}
						else
						{
							SoundAndFlyOver.SetSoundAndFlyOverParameters(None, "", 'ADVENTsighting', eColor_Good);
						}
						break;
					}
				}
			}
		}

		class'X2Action_BlockAbilityActivation'.static.AddToVisualizationTree(ActionMetadata, Context, false, ActionMetadata.LastActionAdded);

		// pause a few seconds
		ActionMetadata.StateObject_OldState = none;
		ActionMetadata.StateObject_NewState = none;
		ActionMetadata.VisualizeActor = none;

		// ignore when in challenge, ladder, etc. mode
		if (!class'X2TacticalGameRulesetDataStructures'.static.TacticalOnlyGameMode())
		{
			DelayAction = X2Action_Delay(class'X2Action_Delay'.static.AddToVisualizationTree(ActionMetadata, Context, false, ActionMetadata.LastActionAdded));
			DelayAction.Duration = 1.0;
		}
	}
}

static protected function EventListenerReturn ScamperBegin (Object EventData, Object EventSource, XComGameState GameState, Name EventID, Object CallbackData)
{
	local XComGameStateContext_RevealAI RevealContext;

	if (IsWhitelisted(XComGameState_AIGroup(EventData))) return ELR_NoInterrupt;

	RevealContext = XComGameStateContext_RevealAI(GameState.GetContext());

	RevealContext.FirstEncounterCharacterTemplate = none;
	RevealContext.FirstSightingMoment = none;

	return ELR_NoInterrupt;
}

///////////////
/// Helpers ///
///////////////

static protected function bool IsWhitelisted (XComGameState_AIGroup GroupState)
{
	local XComGameState_Unit GroupLeaderUnitState;

	// We don't care about getting the correct history frame here, as we only care about the template name - which is the same all the time
	GroupLeaderUnitState = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(GroupState.m_arrMembers[0].ObjectID));

	return default.WhitelistCharaters.Find(GroupLeaderUnitState.GetMyTemplateName()) != INDEX_NONE;
}