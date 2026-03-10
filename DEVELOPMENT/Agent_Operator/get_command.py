import speech_recognition as sr
import subprocess
import sys
import time

def speak(text):
    subprocess.run(['say', '-v', 'Daniel', '-r', '160', text])

def get_voice_command():
    r = sr.Recognizer()
    r.energy_threshold = 300
    r.dynamic_energy_threshold = True
    
    with sr.Microphone() as source:
        # We assume the wake word might have been heard or we are starting fresh
        print("LISTENING_FOR_WAKE_WORD")
        while True:
            try:
                audio = r.listen(source, timeout=None, phrase_time_limit=2)
                text = r.recognize_google(audio).lower()
                
                if "alfred" in text:
                    speak("Yes, sir?")
                    print("WAKE_WORD_DETECTED")
                    
                    # Now listen for the actual command
                    try:
                        audio = r.listen(source, timeout=5, phrase_time_limit=10)
                        command = r.recognize_google(audio)
                        print(f"COMMAND_START")
                        print(command)
                        print(f"COMMAND_END")
                        return command
                    except sr.WaitTimeoutError:
                        return None
                    except sr.UnknownValueError:
                        return None
            except sr.UnknownValueError:
                continue
            except Exception as e:
                print(f"ERROR: {e}")
                return None

if __name__ == "__main__":
    get_voice_command()
