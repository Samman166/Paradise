/obj/item/melee/baton
	name = "stunbaton"
	desc = "A stun baton for incapacitating people with."
	icon_state = "stunbaton"
	var/base_icon = "stunbaton"
	item_state = null
	belt_icon = "stunbaton"
	slot_flags = SLOT_BELT
	force = 10
	throwforce = 7
	origin_tech = "combat=2"
	attack_verb = list("beaten")
	armor = list(MELEE = 0, BULLET = 0, LASER = 0, ENERGY = 0, BOMB = 50, BIO = 0, RAD = 0, FIRE = 80, ACID = 80)
	/// How many seconds does the knockdown last for?
	var/knockdown_duration = 10 SECONDS
	/// how much stamina damage does this baton do?
	var/stam_damage = 60 // 2 hits or 1 hit + 2 disabler shots
	/// Is the baton currently turned on
	var/turned_on = FALSE
	/// How much power does it cost to stun someone
	var/hitcost = 1000
	var/obj/item/stock_parts/cell/high/cell = null
	/// the initial cooldown tracks the time between swings. tracks the world.time when the baton is usable again.
	var/cooldown = 3.5 SECONDS
	/// the time it takes before the target falls over
	var/knockdown_delay = 2.5 SECONDS
	/// how big the baton is while on
	var/w_class_on = WEIGHT_CLASS_HUGE

/obj/item/melee/baton/Initialize(mapload)
	. = ..()
	update_icon()

/obj/item/melee/baton/loaded/Initialize(mapload) //this one starts with a cell pre-installed.
	link_new_cell()
	return ..()

/obj/item/melee/baton/Destroy()
	if(cell?.loc == src)
		QDEL_NULL(cell)
	return ..()

/**
 * Updates the linked power cell on the baton.
 *
 * If the baton is held by a cyborg, link it to their internal cell.
 * Else, spawn a new cell and use that instead.
 * Arguments:
 * * unlink - If TRUE, sets the `cell` variable to `null` rather than linking it to a new one.
 */
/obj/item/melee/baton/proc/link_new_cell(unlink = FALSE)
	if(unlink)
		cell = null
	else if(isrobot(loc.loc)) // First loc is the module
		var/mob/living/silicon/robot/R = loc.loc
		cell = R.cell
	else
		cell = new(src)

/obj/item/melee/baton/suicide_act(mob/user)
	user.visible_message("<span class='suicide'>[user] is putting the live [name] in [user.p_their()] mouth! It looks like [user.p_theyre()] trying to commit suicide.</span>")
	return FIRELOSS

/obj/item/melee/baton

/obj/item/melee/baton/update_icon_state()
	if(turned_on)
		icon_state = "[base_icon]_active"
	else if(!cell)
		icon_state = "[base_icon]_nocell"
	else
		icon_state = "[base_icon]"
/obj/item/melee/baton/examine(mob/user)
	. = ..()
	if(isrobot(user))
		. += "<span class='notice'>This baton is drawing power directly from your own internal charge.</span>"
	if(cell)
		. += "<span class='notice'>The baton is [round(cell.percent())]% charged.</span>"
	else
		. += "<span class='warning'>The baton does not have a power source installed.</span>"

/obj/item/melee/baton/detailed_examine()
	return "The baton needs to be turned on to apply the stunning effect. Use it in your hand to toggle it on or off.  If your intent is \
			set to 'harm', you will inflict damage when using it, regardless if it is on or not. Each stun reduces the baton's charge, which can be replenished by \
			putting it inside a weapon recharger."

/obj/item/melee/baton/get_cell()
	return cell

/**
  * Removes the specified amount of charge from the batons power cell.
  *
  * If `src` is a cyborg baton, this removes the charge from the borg's internal power cell instead.
  * Arguments:
  * * amount - The amount of battery charge to be used.
  */
/obj/item/melee/baton/proc/deductcharge(amount)
	if(!cell)
		return
	cell.use(amount)
	if(cell.rigged)
		cell = null
		turned_on = FALSE
		update_icon(UPDATE_ICON_STATE)
	if(cell.charge < (hitcost)) // If after the deduction the baton doesn't have enough charge for a stun hit it turns off.
		turned_on = FALSE
		w_class = initial(w_class)
		slot_flags = initial(slot_flags)
		update_icon()
		playsound(src, "sparks", 75, TRUE, -1)

/obj/item/melee/baton/attackby(obj/item/I, mob/user, params)
	if(istype(I, /obj/item/stock_parts/cell))
		var/obj/item/stock_parts/cell/C = I
		if(cell)
			to_chat(user, "<span class='warning'>[src] already has a cell!</span>")
			return
		if(C.maxcharge < hitcost)
			to_chat(user, "<span class='warning'>[src] requires a higher capacity cell!</span>")
			return
		if(!user.unEquip(I))
			return
		I.forceMove(src)
		cell = I
		to_chat(user, "<span class='notice'>You install [I] into [src].</span>")
		update_icon(UPDATE_ICON_STATE)

/obj/item/melee/baton/screwdriver_act(mob/living/user, obj/item/I)
	if(!cell)
		to_chat(user, "<span class='warning'>There's no cell installed!</span>")
		return
	if(!I.use_tool(src, user, volume = I.tool_volume))
		return

	user.put_in_hands(cell)
	to_chat(user, "<span class='notice'>You remove [cell] from [src].</span>")
	cell.update_icon()
	cell = null
	turned_on = FALSE
	w_class = initial(w_class)
	slot_flags = initial(slot_flags)
	update_icon(UPDATE_ICON_STATE)

/obj/item/melee/baton/attack_self(mob/user)
	if(cell?.charge >= hitcost)
		turned_on = !turned_on
		to_chat(user, "<span class='notice'>[src] is now [turned_on ? "on" : "off"].</span>")
		playsound(src, "sparks", 75, TRUE, -1)
	else
		if(isrobot(loc))
			to_chat(user, "<span class='warning'>You do not have enough reserve power to charge [src]!</span>")
		else if(!cell)
			to_chat(user, "<span class='warning'>[src] does not have a power source!</span>")
		else
			to_chat(user, "<span class='warning'>[src] is out of charge.</span>")
	update_icon()
	add_fingerprint(user)
	if(turned_on)
		w_class = w_class_on
		slot_flags = null
	else
		w_class = initial(w_class)
		slot_flags = initial(slot_flags)


/obj/item/melee/baton/attack(mob/M, mob/living/user)
	if(turned_on && HAS_TRAIT(user, TRAIT_CLUMSY) && prob(50))
		if(baton_stun(user, user, skip_cooldown = TRUE)) // for those super edge cases where you clumsy baton yourself in quick succession
			user.visible_message("<span class='danger'>[user] accidentally hits [user.p_themselves()] with [src]!</span>",
							"<span class='userdanger'>You accidentally hit yourself with [src]!</span>")
		return

	if(issilicon(M)) // Can't stunbaton borgs and AIs
		return ..()

	if(!isliving(M))
		return
	var/mob/living/L = M

	if(user.a_intent == INTENT_HARM)
		if(turned_on)
			baton_stun(L, user)
		return ..() // Whack them too if in harm intent

	if(!turned_on)
		L.visible_message("<span class='warning'>[user] has prodded [L] with [src]. Luckily it was off.</span>",
			"<span class='danger'>[L == user ? "You prod yourself" : "[user] has prodded you"] with [src]. Luckily it was off.</span>")
		return

	if(baton_stun(L, user))
		user.do_attack_animation(L)

/// returning false results in no baton attack animation, returning true results in an animation.
/obj/item/melee/baton/proc/baton_stun(mob/living/L, mob/user, skip_cooldown = FALSE)
	if(cooldown > world.time && !skip_cooldown)
		return FALSE

	var/user_UID = user.UID()
	if(HAS_TRAIT_FROM(L, TRAIT_WAS_BATONNED, user_UID)) // prevents double baton cheese.
		return FALSE

	cooldown = world.time + initial(cooldown) // tracks the world.time when hitting will be next available.
	if(ishuman(L))
		var/mob/living/carbon/human/H = L
		if(H.check_shields(src, 0, "[user]'s [name]", MELEE_ATTACK)) //No message; check_shields() handles that
			playsound(L, 'sound/weapons/genhit.ogg', 50, TRUE)
			return FALSE
		H.forcesay(GLOB.hit_appends)
		H.Confused(10 SECONDS)
		H.Jitter(10 SECONDS)
		H.adjustStaminaLoss(stam_damage)

	ADD_TRAIT(L, TRAIT_WAS_BATONNED, user_UID) // so one person cannot hit the same person with two separate batons
	addtimer(CALLBACK(src, PROC_REF(baton_knockdown), L, user_UID, knockdown_duration), knockdown_delay)

	SEND_SIGNAL(L, COMSIG_LIVING_MINOR_SHOCK, 33)

	if(user)
		L.lastattacker = user.real_name
		L.lastattackerckey = user.ckey
		L.visible_message("<span class='danger'>[user] has stunned [L] with [src]!</span>",
			"<span class='userdanger'>[L == user ? "You stun yourself" : "[user] has stunned you"] with [src]!</span>")
		add_attack_logs(user, L, "stunned")
	playsound(src, 'sound/weapons/egloves.ogg', 50, TRUE, -1)
	deductcharge(hitcost)
	return TRUE

/obj/item/melee/baton/proc/baton_knockdown(mob/living/target, user_UID, knockdown_duration)
	target.KnockDown(knockdown_duration)
	REMOVE_TRAIT(target, TRAIT_WAS_BATONNED, user_UID)

/obj/item/melee/baton/emp_act(severity)
	. = ..()
	if(cell)
		deductcharge(1000 / severity)

/obj/item/melee/baton/wash(mob/living/user, atom/source)
	if(turned_on && cell?.charge)
		flick("baton_active", source)
		baton_stun(user, user, skip_cooldown = TRUE)
		user.visible_message("<span class='warning'>[user] shocks [user.p_themselves()] while attempting to wash the active [src]!</span>",
							"<span class='userdanger'>You unwisely attempt to wash [src] while it's still on.</span>")
		return TRUE
	..()

//Makeshift stun baton. Replacement for stun gloves.
/obj/item/melee/baton/cattleprod
	name = "stunprod"
	desc = "An improvised stun baton."
	icon_state = "stunprod_nocell"
	base_icon = "stunprod"
	force = 3
	throwforce = 5
	knockdown_duration = 6 SECONDS
	w_class = WEIGHT_CLASS_BULKY
	hitcost = 2000
	slot_flags = SLOT_BACK | SLOT_BELT
	var/obj/item/assembly/igniter/sparkler = null

/obj/item/melee/baton/cattleprod/Initialize(mapload)
	. = ..()
	sparkler = new(src)

/obj/item/melee/baton/cattleprod/Destroy()
	QDEL_NULL(sparkler)
	return ..()

/obj/item/melee/baton/cattleprod/baton_stun(mob/living/L, mob/user, skip_cooldown = FALSE)
	if(sparkler.activate())
		return ..()
