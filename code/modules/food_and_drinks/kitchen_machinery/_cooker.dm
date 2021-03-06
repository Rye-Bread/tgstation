// This folder contains code that was originally ported from Apollo Station and then refactored/optimized/changed.

// Tracks precooked food to stop deep fried baked grilled grilled grilled diona nymph cereal.
/obj/item/reagent_containers/food/snacks/var/list/cooked

// Root type for cooking machines. See following files for specific implementations.
/obj/machinery/cooker
	name = "cooker"
	desc = "You shouldn't be seeing this!"
	icon = 'icons/obj/cooking_machines.dmi'
	density = 1
	anchored = 1
	use_power = 1
	idle_power_usage = 5

	var/on_icon						// Icon state used when cooking.
	var/off_icon					// Icon state used when not cooking.
	var/cooking						// Whether or not the machine is currently operating.
	var/cook_type					// A string value used to track what kind of food this machine makes.
	var/cook_time = 50				// How many ticks the cooking will take.
	var/can_cook_mobs				// Whether or not this machine accepts grabbed mobs.
	var/food_color					// Colour of resulting food item.
	var/cooked_sound				// Sound played when cooking completes.
	var/can_burn_food				// Can the object burn food that is left inside?
	var/burn_chance = 10			// How likely is the food to burn?
	var/obj/item/cooking_obj		// Holder for the currently cooking object.

	// If the machine has multiple output modes, define them here.
	var/selected_option
	var/list/output_options = list()

/obj/machinery/cooker/Destroy()
	if(cooking_obj)
		qdel(cooking_obj)
		cooking_obj = null
	return ..()

/obj/machinery/cooker/proc/set_cooking(new_setting)
	cooking = new_setting
	icon_state = new_setting ? on_icon : off_icon

/obj/machinery/cooker/examine()
	..()
	if(cooking_obj && Adjacent(usr))
		to_chat(usr, "You can see \a [cooking_obj] inside.")

/obj/machinery/cooker/attackby(obj/item/I, mob/user)
	if(!cook_type || (stat & (NOPOWER|BROKEN)))
		to_chat(user, "<span class='warning'>\The [src] is not working.</span>")
		return
	if(cooking)
		to_chat(user, "<span class='warning'>\The [src] is running!</span>")
		return
	if(default_unfasten_wrench(user, I, 20))
		return
	// We're trying to cook something else. Check if it's valid.
	var/obj/item/check = I
//	if(istype(check) && islist(check.cooked) && (cook_type in check.cooked))
//		to_chat(user, "<span class='warning'>\The [check] has already been [cook_type].</span>")
//		return 0
	if(istype(check, /obj/item/reagent_containers/glass))
		to_chat(user, "<span class='warning'>That would probably break [src].</span>")
		return 0
	else if(istype(check, /obj/item/disk/nuclear))
		to_chat(user, "Central Command would kill you if you [cook_type] that.")
		return 0
	else if(!istype(check))
		to_chat(user, "<span class='warning'>That's not edible.</span>")
		return 0
	// We can actually start cooking now.
	user.visible_message("<span class='notice'>\The [user] puts \the [I] into \the [src].</span>")
	cooking_obj = I
	cooking_obj.forceMove(src)
	set_cooking(TRUE)
	icon_state = on_icon

	// Doop de doo. Jeopardy theme goes here.
	sleep(cook_time)

	// Sanity checks.
	if(!cooking_obj || cooking_obj.loc != src)
		cooking_obj = null
		icon_state = off_icon
		set_cooking(FALSE)
		return

	// RIP slow-moving held mobs.
	if(istype(cooking_obj, /obj/item))
		for(var/mob/living/M in cooking_obj.contents)
			M.death()
			qdel(M)

	// Cook the food.
	var/cook_path
	if(selected_option && output_options.len)
		cook_path = output_options[selected_option]
	if(!cook_path)
		cook_path = /obj/item/reagent_containers/food/snacks/variable
	var/obj/item/reagent_containers/food/snacks/result = new cook_path(src) //Holy typepaths, Batman.

	// Set icon and appearance.
	change_product_appearance(result)

	// Update strings.
	change_product_strings(result)

	// Copy reagents over. trans_to_obj must be used, as trans_to fails for snacks due to is_open_container() failing.
	if(cooking_obj.reagents && cooking_obj.reagents.total_volume)
		cooking_obj.reagents.trans_to(result, cooking_obj.reagents.total_volume)

	// Set cooked data.
	var/obj/item/reagent_containers/food/snacks/food_item = cooking_obj
	if(istype(food_item) && islist(food_item.cooked))
		result.cooked = food_item.cooked.Copy()
	else
		result.cooked = list()
	result.cooked |= cook_type

	// Reset relevant variables.
	qdel(cooking_obj)
	src.visible_message("<span class='notice'>\The [src] pings!</span>")
	playsound(src.loc, 'sound/machines/ding.ogg', 50, 1)

	if(!can_burn_food)
		icon_state = off_icon
		set_cooking(FALSE)
		result.forceMove(get_turf(src))
		cooking_obj = null
	else
		var/failed
		var/overcook_period = max(FLOOR(cook_time/5, 1),1)
		cooking_obj = result
		var/count = overcook_period
		while(1)
			sleep(overcook_period)
			count += overcook_period
			if(!cooking || !result || result.loc != src)
				failed = 1
			else if(prob(burn_chance) || count == cook_time)	//Fail before it has a chance to cook again.
				// You dun goofed.
				qdel(cooking_obj)
				cooking_obj = new /obj/item/reagent_containers/food/snacks/badrecipe(src)
				// Produce nasty smoke.
				visible_message("<span class='danger'>\The [src] is burnt and ruined!</span>")
			//	var/datum/effect/effect/system/smoke_spread/bad/smoke = new /datum/effect/effect/system/smoke_spread/bad()
			//	smoke.attach(src)
			//	smoke.set_up(10, 0, usr.loc)
			//	smoke.start()
				failed = 1

			if(failed)
				set_cooking(FALSE)
				icon_state = off_icon
				break

/obj/machinery/cooker/attack_hand(var/mob/user)

	if(cooking_obj && user.Adjacent(src)) //Fixes borgs being able to teleport food in these machines to themselves.
		to_chat(user, "<span class='notice'>You grab \the [cooking_obj] from \the [src].</span>")
		user.put_in_hands(cooking_obj)
		set_cooking(FALSE)
		cooking_obj = null
		icon_state = off_icon
		return

	if(output_options.len)

		if(cooking)
			to_chat(user, "<span class='warning'>\The [src] is in use!</span>")
			return

		var/choice = input("What specific food do you wish to make with \the [src]?") as null|anything in output_options+"Default"
		if(!choice)
			return
		if(choice == "Default")
			selected_option = null
			to_chat(user,  "<span class='notice'>You decide not to make anything specific with \the [src].</span>")
		else
			selected_option = choice
			to_chat(user,  "<span class='notice'>You prepare \the [src] to make \a [selected_option].</span>")

	..()

/obj/machinery/cooker/proc/cook_mob(var/mob/living/victim, var/mob/user)
	return

/obj/machinery/cooker/proc/change_product_strings(var/obj/item/reagent_containers/food/snacks/product)
	if(product.type == /obj/item/reagent_containers/food/snacks/variable) // Base type, generic.
		product.name = "[cook_type] [cooking_obj.name]"
		product.desc = "[cooking_obj.desc] It has been [cook_type]."
	else
		product.name = "[cooking_obj.name] [product.name]"

/obj/machinery/cooker/proc/change_product_appearance(var/obj/item/reagent_containers/food/snacks/product)
	if(product.type == /obj/item/reagent_containers/food/snacks/variable) // Base type, generic.
		product.appearance = cooking_obj
		product.color = food_color
		product.filling_color = food_color

		// Make 'em into a corpse.
		if(istype(cooking_obj, /obj/item))
			var/matrix/M = matrix()
			M.Turn(90)
			M.Translate(1,-6)
			product.transform = M
	else
		var/image/I = image(product.icon, "[product.icon_state]_filling")
		if(istype(cooking_obj, /obj/item/reagent_containers/food/snacks))
			var/obj/item/reagent_containers/food/snacks/S = cooking_obj
			I.color = S.filling_color
		if(!I.color)
			I.color = food_color
		product.overlays += I

