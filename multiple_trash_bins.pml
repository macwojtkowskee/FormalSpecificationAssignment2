/*
	Trash bin system template model for Assignment 2 of 2IX20 - Software Specification.
	Set up for one trash bin and one user.

	This file contains the environment for the single trash bin system part of the assignment.
	It contains:
	- a specification of the trash bin
	- a specification of a simple server
	- a specification of a user
	- a specification of a trash truck
	- a (dummy) specification of the main controller
	- formulas to check the requested properties
*/


// CONSTANTS
// The number of trash bins.
#define NO_BINS 2
// The number of users.
#define NO_USERS 2


// FORMULAS
// Insert the LTL formulas here
ltl ram1_bin0 {[]((bin_status.ram == compress) -> (bin_status[0].out_door == closed && bin_status[0].lock_out_door == closed))};
ltl ram1_bin1 {[]((bin_status.ram == compress) -> (bin_status[1].out_door == closed && bin_status[1].lock_out_door == closed))};

ltl ram2_bin0 {[]((bin_status.ram == idle) -> (bin_status[0].trash_in_outer_door == 0 || bin_status[0].trash_uncompressed == 0 || bin_status[0].trash_on_trap_door == 0))}; 
ltl ram2_bin1 {[]((bin_status.ram == idle) -> (bin_status[1].trash_in_outer_door == 0 || bin_status[1].trash_uncompressed == 0 || bin_status[1].trash_on_trap_door == 0))}; 

ltl door1_bin0 {(bin_status[0].out_door == closed U bin_status[0].trash_in_outer_door == 0)};
ltl door1_bin1 {(bin_status[1].out_door == closed U bin_status[1].trash_in_outer_door == 0)};

ltl door2_bin0 {[](((bin_status[0].trap_door == closed &&  (bin_status[0].trash_on_trap_door == 0) && !process_weigh))-> <>(bin_status[0].lock_out_door == closed))}
ltl door2_bin1 {[](((bin_status[1].trap_door == closed &&  (bin_status[1].trash_on_trap_door == 0) && !process_weigh))-> <>(bin_status[1].lock_out_door == closed))}
// ltl door2_bin0 {(bin_status[0].lock_out_door == open U (bin_status[0].trap_door == closed && bin_status[0].trash_on_trap_door == 0))};
// ltl door2_bin1 {(bin_status[1].lock_out_door == open U (bin_status[1].trap_door == closed && bin_status[1].trash_on_trap_door == 0))};

ltl capacity1_bin0 {[](bin_status[0].full_capacity -> <>!bin_status[0].full_capacity)};
ltl capacity1_bin1 {[](bin_status[1].full_capacity -> <>!bin_status[1].full_capacity)};

ltl user1_bin0 {[](<>!bin_status[0].trash_in_outer_door > 0)};
ltl user1_bin1 {[](<>!bin_status[1].trash_in_outer_door > 0)};

ltl user2_bin0 {[](<>(!has_trash))};
ltl user2_bin1 {[](<>(!has_trash))};

ltl truck1_bin0 {[](truck_requested -> <>(truck_emptied))};
ltl truck1_bin1 {[](truck_requested -> <>(truck_emptied))};
// ltl truck1_bin0 {(truck_emptying_start -> <> truck_emptied)};
// ltl truck1_bin1 {(truck_emptying_start -> <> truck_emptied)};


// DATATYPES
// Type for components
mtype:comp = { OuterDoor, LockOuterDoor, TrapDoor }
// Type for door position.
mtype:pos = { closed, open };
// Type for ram position.
mtype:ram_pos = { idle, compress };
// Type for truck position.
mtype:truck_pos = { arrived, start_emptying, emptied };

// Datatype to store information on the trash bin 
typedef bin_t {
	// Status of doors and ram
	mtype:pos out_door;
	mtype:pos lock_out_door;
	mtype:pos trap_door;
	mtype:ram_pos ram;
	// Location of trash
	byte trash_in_outer_door;
	byte trash_on_trap_door;
	// Current level of trash
	byte trash_compressed;
	byte trash_uncompressed;
	// Exceptional behavior
	bool full_capacity;
	bool trap_destroyed;
}


// VARIABLES
//LTL
bool process_weigh;
// Status of trash bin
bin_t bin_status[NO_BINS+5];

// Maximal capacity of trash bin
byte max_capacity;

// User information
bool has_trash[NO_BINS+5];

// Ram position variables
bool ram_idle;
bool ram_moving;

// Truck variables
bool truck_emptying_start;
bool truck_requested;
bool truck_emptied;
//Track in-use bins
bool bin_in_use[NO_BINS+5];


// CHANNELS
// Asynchronous channel to give command to doors and lock
chan change_bin[NO_BINS+5] = [1] of { mtype:comp, mtype:pos };
// Synchronous channel to acknowledge change in bin
chan bin_changed[NO_BINS+5] = [0] of { mtype:comp, bool };
// Synchronous channel to indicate that user closed the door
chan user_closed_outer_door[NO_BINS+5] = [0] of { bool };

// Synchronous channels to communicate with weight sensors in trap doors
chan weigh_trash[NO_BINS+5] = [0] of { bool };
chan trash_weighted[NO_BINS+5] = [0] of { byte };

// Synchronous channel to communicate with ram
chan change_ram[NO_BINS+5] = [0] of { mtype:ram_pos };
chan ram_changed[NO_BINS+5] = [0] of { bool };

// Asynchronous channel to communicate with the user
chan scan_card_user = [NO_BINS+5] of { byte };
chan can_deposit_trash = [NO_BINS+5] of { byte, bool, byte };

// Synchronous channel to communicate with server
chan check_user = [0] of { byte };
chan user_valid = [0] of { byte, bool };

// Asynchronous channel to communicate with trash truck
chan request_truck = [NO_BINS] of { byte };
chan change_truck = [1] of { mtype:truck_pos, byte };
// Synchronous channel for communication between trash truck and trash bin
chan empty_bin[NO_BINS+5] = [NO_BINS] of { bool };
chan bin_emptied[NO_BINS+5] = [NO_BINS] of { bool };


// PROCESSES
// Trash bin process type.
// It models the physical components (doors, ram, sensors).
proctype bin(byte bin_id) {
	do
	// Outer door
	:: change_bin[bin_id]?OuterDoor, closed ->
		if
		:: bin_status[bin_id].out_door == open ->
			bin_status[bin_id].out_door = closed;
			bin_changed[bin_id]!OuterDoor, true;
			user_closed_outer_door[bin_id]!true;
		fi
	:: change_bin[bin_id]?OuterDoor, open ->
		if
		:: bin_status[bin_id].out_door == closed && bin_status[bin_id].lock_out_door == open ->
			bin_status[bin_id].out_door = open;
			bin_changed[bin_id]!OuterDoor, true;
		fi
	:: change_bin[bin_id]?LockOuterDoor, closed ->
		if
		:: bin_status[bin_id].lock_out_door == open && bin_status[bin_id].out_door == closed ->
			atomic {
				bin_status[bin_id].lock_out_door = closed;
				// Check if trash now falls trough
				if
				:: bin_status[bin_id].trash_in_outer_door > 0 && bin_status[bin_id].trap_door == closed && bin_status[bin_id].trash_on_trap_door == 0 ->
					// Trash in outer door falls on trap door
					bin_status[bin_id].trash_on_trap_door = bin_status[bin_id].trash_in_outer_door;
					bin_status[bin_id].trash_in_outer_door = 0;
				:: bin_status[bin_id].trash_in_outer_door > 0 && bin_status[bin_id].trap_door == closed && bin_status[bin_id].trash_on_trap_door > 0 ->
					// Trash cannot fall through because there is already trash
					skip;
				:: bin_status[bin_id].trash_in_outer_door > 0 && bin_status[bin_id].trap_door == open ->
					// Trash in outer door falls through trap door
					bin_status[bin_id].trash_uncompressed = bin_status[bin_id].trash_uncompressed + bin_status[bin_id].trash_in_outer_door;
					bin_status[bin_id].trash_in_outer_door = 0;
				fi
			}
			bin_changed[bin_id]!LockOuterDoor, true;
		fi
	:: change_bin[bin_id]?LockOuterDoor, open ->
		if
		:: bin_status[bin_id].lock_out_door == closed && bin_status[bin_id].out_door == closed ->
			bin_status[bin_id].lock_out_door = open;
			bin_changed[bin_id]!LockOuterDoor, true;
		fi
	// Trap door
	:: weigh_trash[bin_id]?true ->
		if
		:: bin_status[bin_id].trap_door == closed ->
			trash_weighted[bin_id]!bin_status[bin_id].trash_on_trap_door;
		fi
	:: change_bin[bin_id]?TrapDoor, closed ->
		if
		:: bin_status[bin_id].trap_door == open && bin_status[bin_id].ram == idle ->
			bin_status[bin_id].trap_door = closed;
			bin_changed[bin_id]!TrapDoor, true;
		:: bin_status[bin_id].trap_door == open && bin_status[bin_id].ram == compress ->
			bin_status[bin_id].trap_destroyed = true;
			bin_changed[bin_id]!TrapDoor, false;
		fi
	:: change_bin[bin_id]?TrapDoor, open ->
		if
		:: bin_status[bin_id].trap_door == closed ->
			atomic {
				bin_status[bin_id].trap_door = open;
				// Trash on trap door falls through
				if
				:: bin_status[bin_id].trash_on_trap_door > 0 ->
					bin_status[bin_id].trash_uncompressed = bin_status[bin_id].trash_uncompressed + bin_status[bin_id].trash_on_trap_door;
					bin_status[bin_id].trash_on_trap_door = 0;
				:: else ->
					skip;
				fi
			}
			bin_changed[bin_id]!TrapDoor, true;
		fi
	// Vertical ram
	:: change_ram[bin_id]?compress ->
		if
		:: bin_status[bin_id].ram == idle ->
			atomic {
				bin_status[bin_id].ram = compress;
				if
				:: bin_status[bin_id].trap_door == open ->
					// Compress trash
					bin_status[bin_id].trash_compressed = bin_status[bin_id].trash_compressed + bin_status[bin_id].trash_uncompressed / 2;
					bin_status[bin_id].trash_uncompressed = 0;
				:: bin_status[bin_id].trap_door == closed ->
					// Trap doors are destroyed
					bin_status[bin_id].trap_destroyed = true;
				fi
			}
			ram_changed[bin_id]!true;
		fi
	:: change_ram[bin_id]?idle ->
		if
		:: bin_status[bin_id].ram == compress ->
			bin_status[bin_id].ram = idle;
			ram_changed[bin_id]!true;
		fi
	// Emptying through trash truck
	:: empty_bin[bin_id]?true ->
		if
		:: bin_status[bin_id].out_door == closed && bin_status[bin_id].lock_out_door == closed && bin_status[bin_id].ram == idle ->
			atomic {
				bin_status[bin_id].trash_compressed = 0;
				bin_status[bin_id].trash_uncompressed = 0;
			}
			bin_emptied[bin_id]!true;
			truck_emptied = true;
		fi
	od
}

// Server process type.
// It models the central backend and administration interface.
proctype server() {
	byte user_id;
	do
	// Check validity of card
	:: check_user?user_id ->
		if
		// Do not accept cards from user with id 42
		:: user_id != 42 ->
			user_valid!user_id, true;
		:: user_id == 42 ->
			user_valid!user_id, false;
		fi
	od
}

// Trash truck process type.
// Remodel it to control the trash truck and handle requests by the controller!
proctype truck() {
	byte bin_id;
	do
	:: request_truck?bin_id ->
		// Drive to the trash bin
		truck_emptied = true;
		change_truck!arrived, bin_id;
		truck_emptied = false;
		// Empty the trash bin
		change_truck?start_emptying, bin_id ->
		change_truck!emptied, bin_id;
	od
}


// User process type.
// The user tries to deposit trash.
proctype user(byte user_id; byte trash_size) {
	byte bin_id;
	do
	// Get another bag of trash
	:: !has_trash[user_id] ->
		has_trash[user_id] = true;
	// Try to deposit trash
	:: has_trash[user_id] ->
		// Scan card
		scan_card_user!user_id;
		if
		:: can_deposit_trash?user_id, true, bin_id ->
			bin_changed[bin_id]?LockOuterDoor, true;
			// Open door
			change_bin[bin_id]!OuterDoor, open;
			bin_changed[bin_id]?OuterDoor, true;
			atomic{
				if
				:: bin_status[bin_id].trash_in_outer_door == 0 ->
					// Deposit trash
					bin_status[bin_id].trash_in_outer_door = trash_size;
					has_trash[user_id] = false;
				:: bin_status[bin_id].trash_in_outer_door > 0 ->
					// Cannot deposit trash
					skip;
				fi
			}
			// Close door
			change_bin[bin_id]!OuterDoor, closed;
			bin_changed[bin_id]?OuterDoor, true;
		:: can_deposit_trash?user_id, false, bin_id ->
			skip;
		fi
	od
}


// DUMMY main control process type.
// Remodel it to control the trash bin system and handle requests by users!
proctype main_control() {
	byte user_id;
	bool valid_user;
	byte bin_id;
	byte weight_Trap;
	byte weight_Outer;

	do
	:: scan_card_user?user_id ->
		check_user!user_id;
		user_valid?user_id, valid_user;
		if 
		:: valid_user ->

			// Assign an available bin to the user
      		bool bin_found = false;
			bin_id = 0;  // Declare and initialize bin_id
			do
			:: (bin_id < NO_BINS) ->
				if
				:: (!bin_in_use[bin_id] && !bin_status[bin_id].full_capacity) ->
					bin_in_use[bin_id] = true;  // Mark bin as in use
					bin_found = true;
					break;  // Exit the loop once a bin is found
				:: else ->
					bin_id++;  // Check the next bin
				fi
			:: (bin_id == NO_BINS) -> 
				break;  // Exit the loop when no bins are available
			od;
			if
      		:: bin_found -> 
				can_deposit_trash!user_id, true, bin_id;
				change_bin[bin_id]!LockOuterDoor, open;
				user_closed_outer_door[bin_id]?true ->
				bin_in_use[bin_id] = false;
				weight_Outer = bin_status[bin_id].trash_in_outer_door;
				if
				:: weight_Outer > 0 ->
					change_bin[bin_id]!LockOuterDoor, closed;
					bin_changed[bin_id]?LockOuterDoor, true;
					process_weigh = true;
					weigh_trash[bin_id]!true;
					if 
					:: trash_weighted[bin_id]?bin_status[bin_id].trash_on_trap_door;
						weight_Trap = bin_status[bin_id].trash_on_trap_door;
					fi
					if 
					:: weight_Trap > 0 ->
						change_bin[bin_id]!TrapDoor, open;
						bin_changed[bin_id]?TrapDoor, true;
						change_ram[bin_id]!compress;
						ram_idle = false;
						ram_moving = true;
						ram_changed[bin_id]?true;
						
						change_ram[bin_id]!idle;
						ram_idle = true;
						ram_moving = false;
						ram_changed[bin_id]?true
						
						change_bin[bin_id]!TrapDoor, closed;
						bin_changed[bin_id]?TrapDoor, true;
						process_weigh = false;
						if
						:: bin_status[bin_id].trash_compressed >= max_capacity ->
							bin_status[bin_id].full_capacity = true;
							truck_emptied = false;
							request_truck!bin_id;
							truck_emptying_start = true;
							change_truck?arrived, bin_id;
							change_truck!start_emptying, bin_id;
							change_truck?emptied, bin_id;
							empty_bin[bin_id]!true;
							bin_emptied[bin_id]?true;
							bin_status[bin_id].full_capacity = false;
						:: else ->
							bin_status[bin_id].full_capacity = false;
						fi
					else ->
					:: printf("Error")	//Lack of functionality for when there is no trash in the outer space after truck emptied!
					fi
				fi
			fi
		fi
			
	od
}


// Initial process that instantiates all other processes and
// creates the initial trash bin situation.
init {
	byte proc;
	atomic {
		// In the code below, the individual trash bins are initialised.
		// The assumption here is that N == 1.
		// When generalising the model for multiple bin, make sure that the do-statement is altered!

		byte i = 0;
        do
        :: i < NO_BINS ->
            bin_in_use[i] = false;  // Mark all bins as available at the start
            i++;
        :: else -> break;
        od;

		proc = 0;
		do
		:: proc < NO_BINS ->
			// Status of trash bin
			bin_status[proc].out_door = closed;
			bin_status[proc].lock_out_door = closed;
			bin_status[proc].trap_door = closed;
			bin_status[proc].ram = idle;
			bin_status[proc].trash_in_outer_door = 0;
			bin_status[proc].trash_on_trap_door = 0;
			bin_status[proc].trash_compressed = 0;
			bin_status[proc].trash_uncompressed = 0;
			bin_status[proc].full_capacity = false;
			bin_status[proc].trap_destroyed = false;
			max_capacity = 2;
			run bin(proc);

			//Ram variables:
			ram_idle = true;
			ram_moving = false;

			//Truck variables:
			truck_emptying_start = false;
			truck_emptied = false;

			proc++;
		:: proc == NO_BINS ->
			break;
		od;

		// Start the user process
		proc = 0;
		do
        :: proc < NO_USERS ->
            byte trash_size = 2;
            has_trash[proc] = true;
            run user(proc, trash_size);
            proc++;
        :: proc == NO_USERS -> break;
        od;
		run user(proc, trash_size);

		// Start the server process
		run server();
		// Start the trash truck process
		run truck();

		// Start the control process for the trash bin
		run main_control();
	}
}