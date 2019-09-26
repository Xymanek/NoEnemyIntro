class NEI_CHEventListenerTemplate extends X2EventListenerTemplate;

struct NEI_CHEventListenerTemplate_Event extends X2EventListenerTemplate_EventCallbackPair
{
	var EventListenerDeferral Deferral;
	var int Priority;
};

var protected array<NEI_CHEventListenerTemplate_Event> CHEventsToRegister;

function AddCHEvent(name Event, delegate<X2EventManager.OnEventDelegate> EventFn, optional EventListenerDeferral Deferral = ELD_OnStateSubmitted, optional int Priority = 50)
{
	local NEI_CHEventListenerTemplate_Event EventListener;

	EventListener.EventName = Event;
	EventListener.Callback = EventFn;
	EventListener.Deferral = Deferral;
	EventListener.Priority = Priority;
	CHEventsToRegister.AddItem(EventListener);
}

function RegisterForEvents()
{
	local X2EventManager EventManager;
	local Object selfObject;
	local NEI_CHEventListenerTemplate_Event EventListener;

	EventManager = `XEVENTMGR;
	selfObject = self;

	super.RegisterForEvents();

	foreach CHEventsToRegister(EventListener)
	{
		if(EventListener.Callback != none)
		{
			EventManager.RegisterForEvent(selfObject, EventListener.EventName, EventListener.Callback, EventListener.Deferral, EventListener.Priority);
		}
	}
}

