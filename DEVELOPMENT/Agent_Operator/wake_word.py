import speech_recognition as sr
import subprocess
import time

def speak(text):
    subprocess.run(['say', '-v', 'Daniel', '-r', '160', text])

def listen_for_wake_word():
    r = sr.Recognizer()
    r.energy_threshold = 300 
    r.dynamic_energy_threshold = True
    
    with sr.Microphone() as source:
        print("Alfred is monitoring... (Say 'Alfred' to wake me)")
        while True:
            try:
                audio = r.listen(source, timeout=None, phrase_time_limit=2)
                text = r.recognize_google(audio).lower()
                
                if "alfred" in text:
                    print("Wake word detected!")
                    speak("Yes, sir?")
                    listen_for_command(r, source)
                    print("Alfred is monitoring... (Say 'Alfred' to wake me)")
                    
            except sr.UnknownValueError:
                continue
            except Exception as e:
                print(f"Error: {e}")
                time.sleep(1)

def listen_for_command(recognizer, source):
    print("Listening for command...")
    try:
        audio = recognizer.listen(source, timeout=5, phrase_time_limit=10)
        command = recognizer.recognize_google(audio)
        print(f"Command received: {command}")
        speak(f"I heard you say: {command}. How shall I proceed?")
    except sr.WaitTimeoutError:
        speak("I'm sorry sir, I didn't catch a command.")
    except sr.UnknownValueError:
        speak("I beg your pardon, sir, I couldn't understand that.")

if __name__ == "__main__":
    try:
        listen_for_wake_word()
    except KeyboardInterrupt:
        print("Ceasing monitoring. Good day, sir.")
