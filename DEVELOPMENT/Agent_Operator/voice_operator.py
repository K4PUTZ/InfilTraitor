import speech_recognition as sr
import subprocess
import time
import os
import re
import sys
from apple_vision import recognize_text

# Define the script directory to use absolute paths
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))

CLICLICK_PATH = "/usr/local/bin/cliclick"
CACHE_DIR = os.path.join(SCRIPT_DIR, "cache")

def speak(text):
    print(f"Alfred: {text}")
    subprocess.run(['say', '-v', 'Daniel', '-r', '160', text])

def capture_screen():
    output_path = os.path.join(CACHE_DIR, "screen.png")
    subprocess.run(["screencapture", "-x", output_path], check=True)
    return output_path

def find_and_click(target_text):
    speak(f"Searching for {target_text} on your screen, sir.")
    img_path = capture_screen()
    results = recognize_text(img_path)
    
    # Get screen size to convert normalized coordinates
    # Apple Vision returns normalized coordinates (0-1) with origin at BOTTOM-LEFT
    # cliclick uses logical pixels with origin at TOP-LEFT
    
    # Get main display bounds
    main_display = Quartz.CGDisplayBounds(Quartz.CGMainDisplayID())
    screen_w = main_display.size.width
    screen_h = main_display.size.height
    
    for entry in results:
        if target_text.lower() in entry['text'].lower():
            # bbox: [x, y, width, height] (normalized)
            x, y, w, h = entry['bbox']
            
            # Convert to screen pixels
            # Vision Y is from bottom, so we invert it for cliclick (which is from top)
            center_x = (x + w/2) * screen_w
            center_y = (1 - (y + h/2)) * screen_h
            
            speak(f"Found it. Clicking now.")
            subprocess.run([CLICLICK_PATH, f"c:{int(center_x)},{int(center_y)}"])
            return True
            
    speak(f"I'm sorry, sir. I couldn't find {target_text} on the screen.")
    return False

def open_app(app_name):
    speak(f"Opening {app_name}, sir.")
    script = f'tell application "{app_name}" to activate'
    result = subprocess.run(['osascript', '-e', script], capture_output=True)
    if result.returncode != 0:
        speak(f"I had trouble opening {app_name}. Are you sure it is installed?")

import random

def tell_joke():
    jokes = [
        "Why did the web developer walk out of a restaurant? Because of the table layout.",
        "A SQL query walks into a bar, walks up to two tables, and asks... 'Can I join you?'",
        "How many programmers does it take to change a light bulb? None, that's a hardware problem.",
        "I asked my computer for a joke. it said: 'Your internet connection'.",
        "What is a butler's favorite type of music? A-service!"
    ]
    speak(random.choice(jokes))

def process_command(command):
    command = command.lower()
    
    if "click" in command:
        target = command.split("click")[-1].strip()
        if target:
            find_and_click(target)
        else:
            speak("What would you like me to click, sir?")
            
    elif "open" in command:
        target = command.split("open")[-1].strip()
        if target:
            open_app(target)
        else:
            speak("Which application should I open, sir?")
            
    elif "where am i" in command or "screen" in command:
        speak("I am scanning the screen now.")
        img_path = capture_screen()
        results = recognize_text(img_path)
        if results:
            top_texts = [r['text'] for r in results[:5]]
            speak(f"I see several things, including: {', '.join(top_texts)}")
        else:
            speak("The screen appears to be empty or unreadable at the moment.")

    elif "joke" in command:
        tell_joke()

    elif "thank you" in command or "thanks" in command:
        speak("You are very welcome, sir. It is my pleasure.")

    elif "who are you" in command or "your name" in command:
        speak("I am Alfred, your loyal agent operator. I am here to assist with your macOS tasks.")

    elif "goodbye" in command or "quit" in command:
        speak("Understood, sir. Commencing quitting routine. Good day.")
        subprocess.run(["python3", os.path.join(SCRIPT_DIR, "quit_routine.py")])
        sys.exit(0)
            
    else:
        speak(f"I heard you say: {command}. I am still learning how to handle that specific request, but I have noted it.")

def listen_loop():
    r = sr.Recognizer()
    r.energy_threshold = 300
    r.dynamic_energy_threshold = True
    r.pause_threshold = 1.5 # Wait 1.5s after speech before ending a phrase
    
    with sr.Microphone() as source:
        speak("I am now online and monitoring for your commands, sir.")
        while True:
            try:
                print("Monitoring for 'Alfred'...")
                audio = r.listen(source, timeout=None, phrase_time_limit=2)
                text = r.recognize_google(audio).lower()
                
                if "alfred" in text:
                    speak("Yes, sir?")
                    print("Listening for command...")
                    # Higher phrase_time_limit allows for longer dictations
                    audio = r.listen(source, timeout=10, phrase_time_limit=30)
                    command = r.recognize_google(audio)
                    print(f"User: {command}")
                    process_command(command)
                    
            except sr.UnknownValueError:
                continue
            except sr.WaitTimeoutError:
                pass
            except Exception as e:
                print(f"Error: {e}")
                time.sleep(1)

import Quartz # Needed for screen dimensions
if __name__ == "__main__":
    try:
        if not os.path.exists(CACHE_DIR):
            os.makedirs(CACHE_DIR)
        listen_loop()
    except KeyboardInterrupt:
        speak("Going offline. Good day, sir.")
