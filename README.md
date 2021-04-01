# Task_SpeechMotorSequenceLearning
Phonotactically illegal consonant sequence learning task to run intraoperatively in DBS cases 

Scripts are based on the original SEQMP experimental-code (located in /projectnb/busplab/Experiments/SEQMP, or on the GuetherLab GitHub in the SEQMP repo), with revisions made by Hilary Miller, Ricky Falsini, and Frank Guenther to incorporate some changes based on code from SEQWM and other related SEQ experiments. 

The /scripts directory contains the following code (under construction):

**SEQRun**- (combined runPractice and runTest script to create a single experimental run script)
 	This script will run either a Training session (in response to a 1 in the Training window  	in the GUI) or a Test run (in response to 0). 
 	Code loads a specFile corresponding to the subjName (entered in 1st GUI window), groupNum (entered in 2nd GUI window), and Training/Test (corresponding to 0/1 in 3rd GUI window), all fields separated by '_'. These specFiles can be generated using stimListRandomizer script. 
 	For Training sessions, code requires a button press (space bar) to proceed to the next trial, with trials broken into 3 runs of 60 trials (with a break screen automatically appearing after the 60th trial).

**SEQFamiliarization** - This script will run a short 5 trial training run to ensure participant understands directions and provide feedback on productions prior to starting SEQRun script. 

**stimListRandomizer** - This function requires the following inputs: subject name, groupNum (1-4, same as groupNum designation in SEQRun), and training/test designation (1 for training, 0 for test) and creates a randomized trial list for 3 trained stimuli during training OR mix of
novel and trained stimuli for test phase. The first column of .txt output is the stimulus number; 
second is stimulus type (1 for trained; 2 for novel). This code allows for a different number of repetitions for different stimuli types (e.g. trained items repeat 15x, while untrained only 5).
 	Stimulus type is set according to group designation (where groups 1-4 are each trained on a different set of 3 stimuli).

​	The following parameters can be modified for other paradigm configurations:
 	stimTrained and stimNovel (set by group designation, with numbers corresponding to the stimulus numbering in /stim directory)
 	numReps - number of times each item is repeated (set separately in training v test loops)
 	numTrials - total number of trials, set for Test due to different number of reps for each stimulus set

In the analysis directory - 
**pilotAnalysis** - Analysis code to score accuracy in Matlab using visualization GUI, and then measure duration. Also includes code for descriptive stats/visualization
**pilotAnalysis_dur** - Analysis code only for duration measures (assumes accuracy previously scored using PraatAnalysisCode also in this folder
**PraatAnalysisCode** - Run in Praat, will open a TextGrid along with spectrogram for each audio file with tiers for scoring accuracy on overall word, sequencing errors, error type, and separate accuracy/error type for onset and coda clusters
**SEQ_GUI** - visualization code to create GUI with spectrograms (appears in pilotAnalysis function)
**show_spectrogram** - visualization code to create spectrograms (appears in pilotAnalysis function)

TO DO: 
Review other pilotAnalysis scripts and move any relevant ones to this repo. 
Test SEQ04_GUI and decide between this or Praat script for accuracy analysis. 