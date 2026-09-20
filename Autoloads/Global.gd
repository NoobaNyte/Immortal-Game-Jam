extends Node

signal load_next_level(next_level_path: String, loading_screen_fade_in_time: float, loading_screen_fade_out_time: float)

## set to true when transition_level func is run from any script
## prevents the transition areas from triggering immediately on entering the scene
## gets set to false after you either exit a transition area immediately if not spawned in an area
var player_is_transitioning: bool = false

## gets set when you enter an exit or enter area
## entering is 
enum PlayerTransitionState {FROM_ENTRANCE, FROM_EXIT}

## if set to entering it will take you to the level exit point when you transition levels
## if set to exiting it will take you to the level enter point when you transition levels
var player_transition_state: PlayerTransitionState = PlayerTransitionState.FROM_EXIT

func set_player_transition_state(transition_state: PlayerTransitionState):
     player_is_transitioning = true
     player_transition_state = transition_state