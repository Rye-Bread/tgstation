/mob/living/silicon/robot/mommi/ClickOn(var/atom/A, var/params)
	if(world.time <= next_click)
		return
	next_click = world.time + 1

	if(check_click_intercept(params,A))
		return

	if(stat || lockcharge || IsParalyzed() || IsStun() || IsUnconscious())
		return

	var/list/modifiers = params2list(params)
	if(modifiers["shift"] && modifiers["ctrl"])
		CtrlShiftClickOn(A)
		return
	if(modifiers["shift"] && modifiers["middle"])
		ShiftMiddleClickOn(A)
		return
	if(modifiers["middle"])
		MiddleClickOn(A)
		return
	if(modifiers["shift"])
		ShiftClickOn(A)
		return
	if(modifiers["alt"]) // alt and alt-gr (rightalt)
		AltClickOn(A)
		return
	if(modifiers["ctrl"])
		CtrlClickOn(A)
		return

	if(next_move >= world.time)
		return

	face_atom(A) // change direction to face what you clicked on

	/*
	cyborg restrained() currently does nothing
	if(restrained())
		RestrainedClickOn(A)
		return
	*/

	var/obj/item/W = get_active_held_item()

	if(!W)
		A.attack_mommi(src)
		return

	if(W)
		// buckled cannot prevent machine interlinking but stops arm movement
		if( buckled || incapacitated())
			return

		if(W == A)
			W.attack_self(src)
			return

		if(A == loc || (A in loc) || (A in contents) || A.loc in contents)
			W.melee_attack_chain(src, A, params)
			return

		if(!isturf(loc))
			return

		if(isturf(A) || isturf(A.loc) || (A.loc && isturf(A.loc.loc)))
			if(A.Adjacent(src)) // see adjacent.dm
				W.melee_attack_chain(src, A, params)
				return
			else
				W.afterattack(A, src, 0, params)
				return
	return

//Middle click toggles their module
/mob/living/silicon/robot/mommi/MiddleClickOn(var/atom/A)
	src.toggle_module()
	return


/*
	As with AI, these are not used in click code,
	because the code for robots is specific, not generic.

	If you would like to add advanced features to robot
	clicks, you can do so here, but you will have to
	change attack_robot() above to the proper function
*/
/mob/living/silicon/robot/mommi/UnarmedAttack(atom/A)
	A.attack_mommi(src)
/mob/living/silicon/robot/mommi/RangedAttack(atom/A)
	A.attack_mommi(src)

/atom/proc/attack_mommi(mob/user as mob)
	var/mob/living/silicon/robot/mommi/M = user

	if (src.Adjacent(user))
		if(M.is_in_modules(src) && src.loc.loc == M) //one hell of a hack
			M.activate_module(src)
			M.hud_used.update_robot_modules_display()
			return
		else
			attack_hand(user)
			return
	else
		attack_robot(user)
		return
