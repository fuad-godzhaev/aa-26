**WEEK 2 \[03/02/2026]**

* BOID - https://en.wikipedia.org/wiki/Boids
* Craig Reynolds - creator of BOID
* Ray casts
* Inverse Kinematics (Spider legs movement)
* LLMs
* Assignment 50%; Exam 30%; Lab Test 20%;
* Assignment: create artificial life, preferably in VR/AR, use whatever, but make the player think it's real
* Disney's animator's bible
* (?) ARC raiders animations
* Forces: break force; incident force (reflected force); seek force (?);
* Avoidance behaviour
* Seeking behaviour
* Formation behaviour
* Hash Maps
* Entity Component System (in OOP?)
* Data Oriented Programming / Object Oriented Programming
* Boid:

&nbsp;	Pos -> 3D Vector

&nbsp;	Rotation -> Quaterion - axis/angle

&nbsp;		-> Vector3 - XYZ

&nbsp;		-> angle

&nbsp;	Speed | Velocity

&nbsp;	Force-> accumulator

&nbsp;	Acceleration

&nbsp;	Mass -> Scalar

&nbsp;	Forward

&nbsp;	Angular Velocity

&nbsp;	Angular Acceleration

&nbsp;	Inertial tensor (how 3D objects respond to forces)

&nbsp;	Euler

&nbsp;	Range

* A*(cceleration)* = F*(orce)* / M*(ass)*
* *V(elocity)* = V + A \* \[*delta]*t
* P*(osition)* = P + V \* *\[delta]*t
* F = V / |V|*(forward velocity)*



* desired velocity = T*(point)* - B*(oid)*
* if |V| > max speed -> V = V / |V| \* max speed
* Around point T there is a "slowing distance" in which the boid starts to slow down until it reaches 0 speed
* to\_target = T - B *(distance between point T and boid B)*
* dist = |to\_target| *(length of to\_target)*
* *ramped (ramping down of the speed)* = (dist / slowing\_dist) \* max speed
* clamped = min (ramped, max speed)
* desired = to\_target \* clamped / dist
* return desired - current
