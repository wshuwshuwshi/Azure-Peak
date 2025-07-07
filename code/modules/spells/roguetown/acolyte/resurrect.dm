/obj/effect/proc_holder/spell/invoked/resurrect
	name = "Anastasis"
	overlay_state = "revive"
	releasedrain = 90
	chargedrain = 0
	chargetime = 50
	range = 1
	warnie = "sydwarning"
	no_early_release = TRUE
	movement_interrupt = TRUE
	chargedloop = /datum/looping_sound/invokeholy
	req_items = list(/obj/item/clothing/neck/roguetown/psicross)
	sound = 'sound/magic/revive.ogg'
	associated_skill = /datum/skill/magic/holy
	antimagic_allowed = TRUE
	recharge_time = 10 MINUTES
	miracle = TRUE
	devotion_cost = 250
	var/revive_pq = PQ_GAIN_REVIVE
	var/required_structure = /obj/structure/fluff/psycross
	var/required_items = list(/obj/item/clothing/neck/roguetown/psicross = 1)
	var/item_radius = 1
	var/debuff_type = /datum/status_effect/debuff/revived
	var/structure_range = 1
	var/harms_undead = TRUE

/obj/effect/proc_holder/spell/invoked/resurrect/cast(list/targets, mob/living/user)
	. = ..()
	if(isliving(targets[1]))
		var/mob/living/target = targets[1]
		var/found = FALSE
		for(required_structure in oview(structure_range, target))
			found = TRUE
		if(!found)
			to_chat(user, span_warning("I need a holy [required_structure] near [target]."))
			revert_cast()
			return FALSE
		// if(!target.mind)
		// 	to_chat(user, "This one is inert.")
		// 	revert_cast()
		// 	return FALSE
		if(HAS_TRAIT(target, TRAIT_NECRAS_VOW))
			to_chat(user, "This one has pledged themselves whole to Necra. They are Hers.")
			revert_cast()
			return FALSE
		// if(!target.mind.active)
		// 	to_chat(user, "Necra is not done with [target], yet.")
		// 	revert_cast()
		// 	return FALSE
		if(target == user)
			revert_cast()
			return FALSE
		if(target.stat < DEAD)
			to_chat(user, span_warning("Nothing happens."))
			revert_cast()
			return FALSE
		var/validation_result = validate_items(target)
		if(validation_result != "")
			to_chat(user, span_warning("[validation_result]"))
			revert_cast()
			return FALSE
		if(target.mob_biotypes & MOB_UNDEAD && harms_undead) //positive energy harms the undead
			target.visible_message(span_danger("[target] is unmade by divine magic!"), span_userdanger("I'm unmade by divine magic!"))
			target.gib()
			return TRUE
		if(alert(target, "They are calling for you. Are you ready?", "Revival", "I need to wake up", "Don't let me go") != "I need to wake up")
			target.visible_message(span_notice("Nothing happens. They are not being let go."))
			return FALSE
		target.adjustOxyLoss(-target.getOxyLoss()) //Ye Olde CPR
		if(!target.revive(full_heal = FALSE))
			to_chat(user, span_warning("Nothing happens."))
			revert_cast()
			return FALSE
		var/mob/living/carbon/spirit/underworld_spirit = target.get_spirit()
		//GET OVER HERE!
		if(underworld_spirit)
			var/mob/dead/observer/ghost = underworld_spirit.ghostize()
			qdel(underworld_spirit)
			ghost.mind.transfer_to(target, TRUE)
		target.grab_ghost(force = TRUE) // even suicides
		target.emote("breathgasp")
		target.Jitter(100)
		target.update_body()
		target.visible_message(span_notice("[target] is revived by divine magic!"), span_green("I awake from the void."))
		if(revive_pq && !HAS_TRAIT(target, TRAIT_IWASREVIVED) && user?.ckey)
			adjust_playerquality(revive_pq, user.ckey)
			ADD_TRAIT(target, TRAIT_IWASREVIVED, "[type]")
		target.mind.remove_antag_datum(/datum/antagonist/zombie)
		target.remove_status_effect(/datum/status_effect/debuff/rotted_zombie)	//Removes the rotted-zombie debuff if they have it - Failsafe for it.
		target.apply_status_effect(debuff_type)	//Temp debuff on revive, your stats get hit temporarily. Doubly so if having rotted.
		return TRUE
	revert_cast()
	return FALSE

/obj/effect/proc_holder/spell/invoked/resurrect/cast_check(skipcharge = 0,mob/user = usr)
	if(!..())
		to_chat(user, span_warning("The miracle fizzles."))
		return FALSE
	return TRUE

/obj/effect/proc_holder/spell/invoked/resurrect/proc/validate_items(atom/center)
	var/list/available_items = list()
	var/list/missing_items = list()

	// Scan for items in radius
	for(var/obj/item/I in range(item_radius, center))
		if(I.type in required_items)
			available_items[I.type] += 1

	// Check quantities and compile missing list
	for(var/item_type in required_items)
		var/needed = required_items[item_type]
		var/have = available_items[item_type] || 0
		
		if(have < needed) {
			var/obj/item/I = item_type
			var/amount_needed = needed - have
			missing_items += "[amount_needed] [initial(I.name)][amount_needed > 1 ? "s" : ""] "
		}

	if(length(missing_items))
		var/string = ""
		for(var/item in missing_items)
			string += item 
		return "Missing components: [string]."
	return ""

/obj/effect/proc_holder/spell/invoked/resurrect/proc/consume_items(atom/center)
	for(var/item_type in required_items)
		var/needed = required_items[item_type]

		for(var/obj/item/I in range(item_radius, center))
			if(needed <= 0)
				break
			if(I.type == item_type)
				needed--
				qdel(I)

/obj/effect/proc_holder/spell/invoked/resurrect/abyssor
	name = "test"
	required_items = list(
		/obj/item/reagent_containers/food/snacks/fish/angler = 2,
		/obj/item/reagent_containers/food/snacks/fish/bass = 1
	)
	debuff_type = /datum/status_effect/debuff/dreamfiend_curse

/datum/status_effect/debuff/dreamfiend_curse
	id = "dreamfiend_curse"
	alert_type = /atom/movable/screen/alert/status_effect/dreamfiend_curse
	/// Type of dreamfiend to summon
	var/dreamfiend_type
	var/obj/effect/proc_holder/spell/invoked/summon_dreamfiend_curse/curse_spell

/datum/status_effect/debuff/dreamfiend_curse/on_creation(mob/living/new_owner)
	// Choose dreamfiend type from weighted list
	var/list/dreamfiend_types = list(
		/mob/living/simple_animal/hostile/rogue/dreamfiend = 75,
		/mob/living/simple_animal/hostile/rogue/dreamfiend/major = 24,
		/mob/living/simple_animal/hostile/rogue/dreamfiend/ancient = 1
	)
	dreamfiend_type = pickweight(dreamfiend_types)

	effectedstats = list(
		"strength" = -3,
		"constitution" = -3,
		"endurance" = -3,
		"fortune" = -3,
		"speed" = -3,
		"perception" = -3
	)

	// Add summoning spell to the victim
	if(!new_owner.mind?.has_spell(/obj/effect/proc_holder/spell/invoked/abyssal_strength))
		curse_spell = new(new_owner)
		new_owner.mind?.AddSpell(curse_spell)
		curse_spell.dreamfiend_type = dreamfiend_type

	return ..()

/atom/movable/screen/alert/status_effect/dreamfiend_curse
	name = "Abyssal curse."
	desc = "A nightmare entity has revived you, but now it is draining your vitality. Summon it to confront it."
	//icon_state = "dreamfiend_curse"

/obj/effect/proc_holder/spell/invoked/summon_dreamfiend_curse
	name = "Confront Terror"
	desc = "Summon the dreamfiend haunting you to confront it directly"
	//overlay_state = "dreamfiend"
	chargetime = 0
	invocation = "Face me daemon!"
	invocation_type = "shout"
	sound = 'modular_azurepeak/sound/mobs/abyssal/abyssal_teleport.ogg'
	/// Type of dreamfiend to summon
	var/dreamfiend_type
	recharge_time = 600 SECONDS

/obj/effect/proc_holder/spell/invoked/summon_dreamfiend_curse/cast(list/targets, mob/living/user)
	// Summon the dreamfiend
	if(summon_dreamfiend(
		target = user,
		user = user,
		F = dreamfiend_type,
		outer_tele_radius = 6,
		inner_tele_radius = 5
	))
		// Remove the curse after summoning
		user.remove_status_effect(/datum/status_effect/debuff/dreamfiend_curse)
		user.mind.RemoveSpell(src)
		return TRUE
	
	to_chat(user, span_warning("No valid space to manifest the nightmare!"))
	return FALSE
