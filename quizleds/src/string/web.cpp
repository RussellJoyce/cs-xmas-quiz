#include <web.h>
#include <settings.h>
#include <Arduino.h>
#include <net.h>
#include <animation.h>


//Protocol:
//All numbers are fixed-width decimal. Team ids tt are 0-based.
// Set animation
//   a00 - off
//   a01 - megamas
//   a02 - timer twinkle
//   a03 - swell
//   a04 - embers
//   a05 - old christmas lights
//   Any other id is logged and ignored.
// Buzz for a team
//   btt - play the next buzzer animation in the rotation, ending on team tt's colour
// Set colour
//   crrrgggbbb - set the string to the specified rgb colour, components are ints 0-255
// Set team colour
//   ttt - set the string to the colour of team tt
// Set animation target to a team
//   ett - set the fade target of every LED to team tt's hue, which animations that fade
//         towards their target (megamas) then pick up
// Colour pulse
//   p00 - pulse string white
//   p01 - pulse string red
//   p02 - pulse string green
//   Any other value pulses white.
// Team pulse
//   qtt - slow pulse of team tt's colour
//   qTT - where TT >= 50, quick pulse of team TT-50's colour
// Music levels
//   mlllLLLrrrRRR - left average, left peak, right average, right peak, in LEDs (0-100).
//                   The right channel fills from the left end of the line, and the left
//                   channel from the right end.
// Number of team colours
//   ntt - divide the hue wheel into tt equal slices for team colours (default 14), so team t
//         has hue t/tt and teams wrap after tt. 00 is ignored. Takes effect from the next
//         animation or command that picks up a team colour.
// Counter
//   rxxx - light xxx LEDs (0 to NUM_LEDS) white from the left; the rest fade out from
//          random colours


//The WiFi and websocket transport is in net.cpp, shared with the trees. The string connects
//with no query, which is how the server knows it is the string.

void print_wifi_details() {
	net_print_details();
}

void connectWifi() {
	net_begin(HOSTNAME, NULL);
}

uint8_t bytesToInt(char *b) {
	return 100*(b[0]-'0') + 10*(b[1]-'0') + (b[2]-'0');
}

uint8_t bytesToInt2(char *b) {
	return 10*(b[0]-'0') + (b[1]-'0');
}


static void handle_command(char *dat, int command_length) {
	switch(dat[0]) {
		case 'a': { //Set to a canned animation
			uint8_t animnum = bytesToInt2(&dat[1]);
			switch(animnum) {
				case 0:
					Serial.println("Anim: None");
					anim_set_anim(NONE, 0);
					break;
				case 1:
					Serial.println("Anim: Megamas");
					anim_set_anim(MEGAMAS, 0);
					break;
				case 2:
					Serial.println("Anim: Timer twinkle");
					anim_set_anim(TIMERTWINKLE, 0);
					break;
				case 3:
					Serial.println("Anim: Swell");
					anim_set_anim(SWELL, 0);
					break;
				case 4:
					Serial.println("Anim: Embers");
					anim_set_anim(EMBERS, 0);
					break;
				case 5:
					Serial.println("Anim: Old lights");
					anim_set_anim(OLDLIGHTS, 0);
					break;
				default:
					Serial.printf("Unknown animation %d\n", animnum);
					break;
			}
			break;
		}
		case 'b': { //A team is buzzing
			uint8_t teamid = bytesToInt2(&dat[1]);
			Serial.printf("Buzz %d\n", teamid);
			anim_buzz_team(teamid);
			break;
		}
		case 'c': { //Set the string to a specific colour
			if(command_length >= 10) {
				uint8_t r = bytesToInt(&dat[1]);
				uint8_t g = bytesToInt(&dat[4]);
				uint8_t b = bytesToInt(&dat[7]);
				setLEDsNoAnim(RgbColor(r, g, b));
			}
			break;
		}
		case 'e': { //Set the fade target of the string to a specific team's colour
			uint8_t teamid = bytesToInt2(&dat[1]);
			setTargetToTeam(teamid);
			break;
		}
		case 't': { //Set the string to a specific team's colour without animation
			uint8_t teamid = bytesToInt2(&dat[1]);
			Serial.printf("TeamCol %d\n", teamid);
			setLEDsNoAnim(team_col(teamid));
			break;
		}
		case 'p': { //Pulse the string a specific colour
			uint8_t param = bytesToInt2(&dat[1]);
			Serial.printf("Pulse col %d\n", param);
			anim_set_anim(COLOURPULSE, param);
			break;
		}
		case 'q': { //Pulse a specific team's colour
			uint8_t param = bytesToInt2(&dat[1]);
			Serial.printf("Pulse team %d\n", param);
			anim_set_anim(TEAMPULSE, param);
			break;
		}
		case 'm': { //Set music levels for the left and right channels
			if(command_length >= 13) {
				uint8_t la = bytesToInt(&dat[1]);
				uint8_t lp = bytesToInt(&dat[4]);
				uint8_t ra = bytesToInt(&dat[7]);
				uint8_t rp = bytesToInt(&dat[10]);
				set_music_levels(la, lp, ra, rp);
			}
			break;
		}
		case 'n': { //Set how many teams the hue wheel is shared between
			uint8_t n = bytesToInt2(&dat[1]);
			Serial.printf("Team hue slices %d\n", n);
			if(n > 0) team_hue_slices = n;
			break;
		}
		case 'r': { //Set the string to a counter of LEDs lit
			if(command_length >= 4) {
				int c = (int) bytesToInt(&dat[1]);
				anim_set_anim(COUNTER, c);
			}
			break;
		} 
		default:
			Serial.printf("LED Command %c\n", dat[0]);
			break;
	}
}

void network_tick() {
	net_tick(handle_command);
}
