#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <store>

#define SERVER_MAX_CLIENTS 70

//Variables
int g_EffectEntity[SERVER_MAX_CLIENTS]; //holds info_particle_system entities
char g_EffectName[SERVER_MAX_CLIENTS][256];
bool g_bHide[SERVER_MAX_CLIENTS];
char g_StoreEffectName[2048][256];
int g_NumTotalEffects;

//Cvars
ConVar cvar_particle_file_name = null;

public Plugin myinfo =
{
  name = "Particle Trails",
  author = "Invex | Byte",
  description = "Store plugin to add particle trails.",
  version = "1.00",
  url = "http://www.invexgaming.com.au"
};

public void OnPluginStart()
{
  Store_RegisterHandler("ParticleTrail", "Effect", ParticleTrailsOnMapStart, ParticleTrailsReset, ParticleTrailsConfig, ParticleTrailsEquip, ParticleTrailsRemove, true, false);
  
  cvar_particle_file_name = CreateConVar("sm_store_particletrails_pcfname", "fx.pcf", "The name of the particle file to load (def. fx.pcf)");
  
  HookEvent("round_start", round_start);
  HookEvent("round_end", round_end);
  HookEvent("player_death", player_death);
  HookEvent("player_spawn", player_spawn);
  HookEvent("player_disconnect", player_disconnect);
  
  //Create config file
  AutoExecConfig(true, "particletrails");
}

public void OnMapStart()
{
  char pcfName[PLATFORM_MAX_PATH];
  GetConVarString(cvar_particle_file_name, pcfName, sizeof(pcfName));
  Format(pcfName, sizeof(pcfName), "particles/%s", pcfName);
  
  AddFileToDownloadsTable(pcfName);
  PrecacheGeneric(pcfName, true); 
}

public void ParticleTrailsOnMapStart()
{
  return;
}

public void ParticleTrailsReset()
{
  g_NumTotalEffects = 0;
}

public bool ParticleTrailsConfig(Handle &kv, int itemid)
{
  Store_SetDataIndex(itemid, g_NumTotalEffects);
  KvGetString(kv, "Effect", g_StoreEffectName[g_NumTotalEffects], 256, "");
  ++g_NumTotalEffects;
  return true;
}

public int ParticleTrailsEquip(int client, int id)
{
  int m_iData = Store_GetDataIndex(id);

  g_EffectName[client] = g_StoreEffectName[m_iData]; //set effect name
  
  if (g_EffectEntity[client])
    RemoveParticleTrail(client);
  
  GiveParticleTrail(client);
  return 0;
}

public int ParticleTrailsRemove(int client)
{
  Format(g_EffectName[client], sizeof(g_EffectName[]), ""); //reset effect name
  RemoveParticleTrail(client);
  return 0;
}

public Action round_start(Handle event, char[] name, bool dontBroadcast)
{
  CreateTimer(1.0, Timer_GiveParticleTrail);
}

public Action Timer_GiveParticleTrail(Handle timer)
{
  for (int i = 1; i <= MaxClients; ++i) {
    if (IsClientInGame(i) && IsPlayerAlive(i)) {
      GiveParticleTrail(i);
    }
  }
  
  return Plugin_Continue;
}

public Action round_end(Event event, char[] name, bool dontBroadcast)
{
  for (int i = 1; i <= MaxClients; ++i) {
    g_EffectEntity[i] = 0;
  }
  
  return Plugin_Continue;
}

public Action player_death(Event event, char[] name, bool dontBroadcast)
{
  int client = GetClientOfUserId(event.GetInt("userid"));
  RemoveParticleTrail(client);
  return Plugin_Continue;
}

public Action player_spawn(Event event, char[] name, bool dontBroadcast)
{
  int client = GetClientOfUserId(event.GetInt("userid"));
  GiveParticleTrail(client); 
  return Plugin_Continue;
}

public Action player_disconnect(Event event, char[] name, bool dontBroadcast)
{
  int client = GetClientOfUserId(event.GetInt("userid"));
  g_EffectEntity[client] = 0;
  return Plugin_Continue;
}

void RemoveParticleTrail(int client) 
{
  if (g_EffectEntity[client]) {
    if (IsClientInGame(client)) {
      if (IsValidEdict(g_EffectEntity[client])) {
        AcceptEntityInput(g_EffectEntity[client], "Kill", -1, -1);
      }
    }
    g_EffectEntity[client] = 0;
  }
}

void GiveParticleTrail(int client)
{
  if (IsClientInGame(client) && IsPlayerAlive(client)) {
    if (g_EffectEntity[client])
      RemoveParticleTrail(client);
    
    //Apply particle trail if effect name isn't empty
    if (!StrEqual(g_EffectName[client], "")) {
      float clientOrigin[3];
      GetClientAbsOrigin(client, clientOrigin);
      g_EffectEntity[client] = CreateEntityByName("info_particle_system", -1);
      DispatchKeyValue(g_EffectEntity[client], "start_active", "0");
      DispatchKeyValue(g_EffectEntity[client], "effect_name", g_EffectName[client]);
      DispatchSpawn(g_EffectEntity[client]);
      TeleportEntity(g_EffectEntity[client], clientOrigin, NULL_VECTOR, NULL_VECTOR);
      ActivateEntity(g_EffectEntity[client]);
      SetVariantString("!activator");
      AcceptEntityInput(g_EffectEntity[client], "SetParent", client, g_EffectEntity[client]);
      CreateTimer(0.25, Timer_Run, g_EffectEntity[client]);
      SDKHook(g_EffectEntity[client], SDKHook_SetTransmit, Hook_SetTransmit);
    }
  }
}

public Action Timer_Run(Handle timer, int entity)
{
  if (entity > 0 && IsValidEntity(entity))
    AcceptEntityInput(entity, "Start", -1, -1);
}

public Action Hook_SetTransmit(int entity, int client)
{
  if (g_bHide[client]) {
    //Block visibility of effect
    return Plugin_Handled;
  }
  
  //Allow visibility of effect
  
  return Plugin_Continue;
}
