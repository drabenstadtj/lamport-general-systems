# Bugs

- going backwards from entry level back to the arrival level retriggers the starting cutscene'
- the log files in subnet1 were not there
- one inactive server shows a yellow light in the subnet1

# UX

- the goal of the entry level differing from the subnet1 is confusing because the loop changes and hasnt been established yet
- in the entry level demo players would go to the servers and do that step before the rest (move, look, zoom, terminal) and it would cause the network being fixed not to register

- it is confusing to have to connect to one of the servers to view the logs for the whole network
- players missed the exit door in subnet1, going to the rest of the level and never noticing the exit
- given the size of the area the speed of the robots is too high and they are too hard to get away from
- the damn robots movement is janky
- mightve been because of the trackpad but everyone tried to use F to zoom while already viewing a note (not sure if i wnat them to be able to do this)
- terminology for various states of the network must be either introduced better or consolidated to more clear and common terms

# Player 1:

### Watch For

| Area                                              | Y/N | Notes                                                                                                                                                                               |
| ------------------------------------------------- | --- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Player observes before acting                     | y   | player checked help messages and tried various commands                                                                                                                             |
| Player reads logs/docs voluntarily                | n   | read logs after being prompted by environmental notes                                                                                                                               |
| Player understands what each terminal command did | m   | for the most part, consensus command could use clarification/emphasis                                                                                                               |
| Player predicts network response                  | m   |                                                                                                                                                                                     |
| Player notices network reacting to their actions  | y   | checked network and status command and noticed changes                                                                                                                              |
| Player mixes terminal + physical approaches\*     | y   | player used a mix                                                                                                                                                                   |
| First robot encounter lands                       | n   | didnt have the scary feeling i intend, however it was in a loud environemnt                                                                                                         |
| Detection feels fair                              | y   | _detection_ was fair (could even be more intense) but robots were too fast and impossible to escape, led to players simply running away for the robot to catch up and running again |
| Player triggers consensus (how/when?)             | y   | subnet 1                                                                                                                                                                            |
| Player gets stuck (where?)                        | y   | in subnet 1 player missed the goal/exit door                                                                                                                                        |
| "Aha" moment happens (what?)                      | n   |                                                                                                                                                                                     |

# Player 2 (Aza):

### Watch For

| Area                                              | Y/N | Notes                                                                                                     |
| ------------------------------------------------- | --- | --------------------------------------------------------------------------------------------------------- |
| Player observes before acting                     | y   |                                                                                                           |
| Player reads logs/docs voluntarily                | y   |                                                                                                           |
| Player understands what each terminal command did | m   |                                                                                                           |
| Player predicts network response                  | y   |                                                                                                           |
| Player notices network reacting to their actions  | y   |                                                                                                           |
| Player mixes terminal + physical approaches\*     | y   |                                                                                                           |
| First robot encounter lands                       | y   |                                                                                                           |
| Detection feels fair                              | y   |                                                                                                           |
| Player triggers consensus (how/when?)             | y   |                                                                                                           |
| Player gets stuck (where?)                        | y   | subnet1 terminal both not knowin the door was open, not knowing to run consensus command to let it happen |
| "Aha" moment happens (what?)                      | y   | consensus                                                                                                 |

# Player 3:

### Watch For

| Area                                              | Y/N | Notes                                                                                                     |
| ------------------------------------------------- | --- | --------------------------------------------------------------------------------------------------------- |
| Player observes before acting                     | n   | jumped straight to the terminal, typed random commands to see what would happen                           |
| Player reads logs/docs voluntarily                | n   | never opened logs                                                                                         |
| Player understands what each terminal command did | n   | crash and corrupt were treated as interchangeable, didn't notice different effects / was confused by them |
| Player predicts network response                  | n   |                                                                                                           |
| Player notices network reacting to their actions  | m   | noticed status changes but didn't connect them to their own actions                                       |
| Player mixes terminal + physical approaches\*     | y   |                                                                                                           |
| First robot encounter lands                       | n   |                                                                                                           |
| Detection feels fair                              | m   | understood when detected but couldn't escape robots too fast                                              |
| Player triggers consensus (how/when?)             | n   | never triggered consensus, missed the door entirely                                                       |
| Player gets stuck (where?)                        | y   | subnet1 didnt notice exit door, explored the rest of the level looking for objective                      |
| "Aha" moment happens (what?)                      | n   |                                                                                                           |

### Player Survey

1. **What were you trying to do most of the time?**
   figuring out what terminal commands did — ran commands repeatedly while watching the status screen, unclear whether making progress or making things worse.

2. **How well did you understand the node states (healthy / crashed / byzantine)? (1=lost, 5=got it)** 2
   healthy made sense; crashed and byzantine felt identical.

3. **Was there a moment the network made sense to you? What caused it?**
   no.

4. **What part of the network was most confusing?**

5. **How did the terminal feel? (1=frustrating, 5=satisfying)** 2
   unclear whether inputs were doing anything meaningful.

6. **What was your approach?**
   trial and error at terminals; avoided the robot, mostly stayed at machines.

7. **Did you feel like you had a choice in how to handle problems? (1=one right answer, 5=many options)** 2
   no, didn't understand the options well enough to choose between them.

8. **Did you notice the network reacting to your actions? (Yes / Vaguely / No)**
   saw numbers change but didn't connect them to own actions.

9. **When detected, did you understand why? (1=never, 5=always)** 4

10. **Pacing? (Too slow / Right / Too fast)** Too slow
    outside of time spent problem solving things were somewhat slow between demo and subnet1

11. **Difficulty? (Too easy / Right / Too hard)** hard

12. **Did you know you could run consensus to open the door? (Yes / Eventually / No)** no, but required hint

13. **Was it clear that crashing vs corrupting a node did different things? (1=no difference, 5=totally clear)** 1
    no difference perceived.

14. **Was the repair/destroy choice clear? (Yes / Mostly / No)** not at all

15. **Did it feel like it mattered? (1=didn't care, 5=felt heavy)** 2

16. **Best moment?**
    robot coming around a corner unexpectedly, described as tense.

17. **Most frustrating moment?**
    wandered subnet1 for a long time not knowing the exit door was back in the original hallway

18. **One thing you'd change?**
    wanted a hint when stuck, even just a nudge pointing to unchecked areas.

19. **Would you keep playing? (Yes / Probably / No)** Probably
