# ****************************************************************************************
# Runs the 'SwimOrDie' simulation where the strength of the force field in zone 1 is increased by
# 0.00001 every TIMESTEPS_PER_ITERATION
# ****************************************************************************************


import argparse
import re
import subprocess
import csv
import json
import shutil
from time import sleep
from progress.bar import Bar
from datetime import datetime, timedelta
import threading

# paths
ALIEN_PATH = '/home/pheonix/alien/build/'  # path to alien.exe
SIM_PATH = '/home/pheonix/aliensims/sophie_div_res/a/'  # path to itr0.sim

# algorithm parameters
TIMESTEPS_PER_ITERATION = 100_000

process_stdout = None

def get_base_filename(iteration):
    return "itr" + str(iteration)

def run_cli(iteration):
    input_filename = get_base_filename(iteration) + ".sim"
    output_filename = get_base_filename(iteration + 1) + ".sim"
    # print(f"Execute {input_filename} -> {output_filename}")
    command = [ALIEN_PATH + "cli", "-i", SIM_PATH + input_filename, "-o", SIM_PATH + output_filename, "-t", str(TIMESTEPS_PER_ITERATION)]
    completed_process = subprocess.run(command, capture_output=True)
    global process_stdout
    process_stdout = completed_process.stdout

def set_zone1_flow_strength(iteration, flow_strength):
    filename = get_base_filename(iteration) + ".settings.json"
    with open(SIM_PATH + filename, 'r') as paramfile:
        params_json = json.load(paramfile)
    params_json['simulation parameters']['spots']['0']['flow']['linear']['strength'] = flow_strength
    with open(SIM_PATH + filename, 'w') as paramfile:
        paramfile.write(json.dumps(params_json, indent=4))

def copy_sim(input, output):
    shutil.copy(input + '.sim', output + '.sim')
    shutil.copy(input + '.settings.json', output + '.settings.json')
    shutil.copy(input + '.statistics.csv', output + '.statistics.csv')

def main():
    iteration = 540
    flow_strength = 0.00001  # Set init value
    process = None  # This will hold the subprocess
    tps = 250.0  # Default value, will be updated

    while True:
        print("*******************************************")
        print(f"Iteration {iteration}")
        print(f'Simulation started at {datetime.now().strftime("%H:%M:%S")}')
        print(f'Number of timesteps: {TIMESTEPS_PER_ITERATION}')
        print(f'Estimated completion time {timedelta(seconds=int(TIMESTEPS_PER_ITERATION / tps))}')
        print("*******************************************")

        # Run the simulation in another thread to keep UI responsive
        process = threading.Thread(target=run_cli, args=(iteration,))
        process.start()

        max_seconds = int(TIMESTEPS_PER_ITERATION / tps)
        bar = Bar('Processing', max=max_seconds)

        while process.is_alive():
            sleep(1)    # Wait a second
            bar.next()  # Update the progress bar

        bar.finish()

        out_string = process_stdout.decode("utf-8")
        
        # Find 'TPS'
        pattern = r'(\d+(\.\d+)?)\s*TPS'
        match = re.search(pattern, out_string)
        if match:
            tps = float(match.group(1))  # Convert the found number to float
        else:
            tps = 250.0
        
        # Split the data into lines
        lines = out_string.split('\n')
        # Extract the line containing "Simulation finished"
        for line in lines:
            if "Simulation finished" in line:
                print(line) 
                
        print(f'Saving simulation to {SIM_PATH + get_base_filename(iteration + 1)}')
 
        # Mutate parameters on the new iteration
        # print(f'Mutating simulation {get_base_filename(iteration + 1)} to have flow strength {flow_strength + 0.00001:.6f}')
        # flow_strength += 0.00001
        # set_zone1_flow_strength(iteration + 1, flow_strength)

        iteration += 1
        print()
        print()

if __name__ == "__main__":
    main()




# simulation parameters, spots, 0, flow, linear, strength

def read_zone1_flow_strength(iteration):
    filename = get_base_filename(iteration) + ".settings.json"
    with open(SIM_PATH + filename, newline='') as paramfile:
       params = json.loads(paramfile)
       return params['simulation parameters']['spots'][0]['flow']['linear']['strength']

    # parser = argparse.ArgumentParser(description='Run SwimOrDie simulation with incremental updates')
    # parser.add_argument('integers', metavar='N', type=int, nargs='+',
    #                     help='an integer for the accumulator')
    # parser.add_argument('--sum', dest='accumulate', action='store_const',
    #                     const=sum, default=max,
    #                     help='sum the integers (default: find the max)')

    # args = parser.parse_args() 
