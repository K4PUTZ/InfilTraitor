import subprocess
import time
import os

# Define the script directory to use absolute paths for subprocess calls
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))

def speak(text):
    subprocess.run(['python3', os.path.join(SCRIPT_DIR, 'speak.py'), text])

def run_brain():
    speak("The brain is now active and monitoring your commands, sir.")
    while True:
        try:
            # Call get_command.py and capture its output
            result = subprocess.run(['python3', os.path.join(SCRIPT_DIR, 'get_command.py')], capture_output=True, text=True)
            output = result.stdout
            
            if "COMMAND_START" in output:
                # Extract the command between COMMAND_START and COMMAND_END
                start_marker = "COMMAND_START\n"
                end_marker = "\nCOMMAND_END"
                if start_marker in output and end_marker in output:
                    command = output.split(start_marker)[1].split(end_marker)[0].strip()
                    print(f"Brain received: {command}")
                    
                    # Log the command to a file for the main Gemini Agent (me) to see
                    # Ensure cache directory exists relative to this script
                    cache_dir = os.path.join(SCRIPT_DIR, "cache")
                    if not os.path.exists(cache_dir):
                        os.makedirs(cache_dir)
                    
                    request_file = os.path.join(cache_dir, "brain_request.txt")
                    response_file = os.path.join(cache_dir, "brain_response.txt")
                    
                    # Clear any old response
                    if os.path.exists(response_file):
                        os.remove(response_file)
                        
                    with open(request_file, "w") as f:
                        f.write(command)
                    
                    speak(f"Processing, sir.")
                    
                    # Wait for Gemini Agent (me) to process and write response
                    start_wait = time.time()
                    answered = False
                    while time.time() - start_wait < 30: # 30 second timeout
                        if os.path.exists(response_file):
                            with open(response_file, "r") as f:
                                response = f.read().strip()
                            if response:
                                speak(response)
                                answered = True
                                break
                        time.sleep(1)
                    
                    if not answered:
                        speak("I am sorry, sir. The brain is not responding at the moment.")
                    
                    # Cleanup request file to indicate it was processed
                    if os.path.exists(request_file):
                        os.remove(request_file)
            
        except Exception as e:
            print(f"Brain Error: {e}")
            time.sleep(1)

if __name__ == "__main__":
    run_brain()
