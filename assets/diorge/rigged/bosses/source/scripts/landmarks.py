# Boss joint landmarks in pixel coords of the 512px front render (px, py); "side" ranges use the side render.
# Character faces -Y. ".L" = character's left = +X = image right in the front render.
# weapon: hand that holds the weapon ("R" = image left). tail_front: chain read on the FRONT render (fish/snake body).
MODELS = {
    "curupira": {
        "style": "melee", "robe": False, "weapon": "R",
        "spine": [(288, 345), (288, 300), (288, 250), (288, 200), (288, 185)], "head_top": (288, 80),
        "arm.L": [(340, 215), (355, 285), (365, 325)], "hand_tip.L": (368, 345),
        "arm.R": [(240, 215), (220, 290), (205, 335)], "hand_tip.R": (195, 355),
        "leg.L": [(310, 370), (318, 425), (322, 465)], "leg.R": [(262, 370), (258, 425), (255, 465)],
        # club: visible end left of the hand, plus the part that sticks out behind the hip (side render)
        "rigid": [("hand.R", (130, 215), (320, 400), None), ("hand.R", (200, 300), (255, 345), (285, 400))],
    },
    "iara": {
        "style": "cast", "robe": False, "weapon": "R",
        "spine": [(305, 265), (303, 228), (300, 190), (298, 152), (296, 135)], "head_top": (293, 85),
        "arm.L": [(345, 180), (362, 230), (372, 270)], "hand_tip.L": (378, 295),
        "arm.R": [(262, 175), (238, 205), (215, 205)], "hand_tip.R": (205, 200),
        # fish tail instead of legs: hips -> down -> curls to image left -> fin
        "tail_front": [(305, 265), (312, 330), (318, 395), (305, 450), (270, 470), (225, 450), (190, 415), (160, 385)],
        "tail_axis": "X", "tail_amp": 5,
        # trident: head above the hand and shaft below; side range keeps the hair and tail out
        "rigid": [("hand.R", (155, 285), (20, 180), (150, 200))],
        # the shaft crosses the tail: pick it by its cyan paint (the tail is green)
        # (bone, front polyline, radius px, side y px range, colour test)
        "rigid_color": [("hand.R", [(212, 200), (225, 260), (240, 330), (250, 395), (235, 470), (232, 495)], 24, (140, 205), "not_green")],
    },
    "matinta": {
        "style": "cast", "robe": True, "weapon": "R",
        "spine": [(258, 320), (255, 275), (250, 220), (248, 160), (248, 140)], "head_top": (248, 65),
        "arm.L": [(300, 170), (320, 225), (285, 250)], "hand_tip.L": (265, 255),
        "arm.R": [(210, 170), (185, 215), (150, 175)], "hand_tip.R": (140, 165),
        "leg.L": [(290, 345), (295, 410), (300, 465)], "leg.R": [(225, 345), (220, 410), (218, 465)],
        "rigid": [("hand.R", (100, 200), (15, 505), (95, 222))],
    },
    # ---------------- mobs3 (rigged/mobs) ----------------
    "jacare_acu": {
        "style": "melee", "robe": False, "weapon": "R",
        "spine": [(262, 300), (262, 265), (262, 215), (262, 150), (262, 120)], "head_top": (262, 65),
        "arm.L": [(330, 165), (370, 230), (375, 280)], "hand_tip.L": (378, 310),
        "arm.R": [(200, 165), (160, 235), (155, 285)], "hand_tip.R": (160, 300),
        "leg.L": [(295, 320), (305, 380), (310, 430)], "leg.R": [(225, 320), (215, 380), (205, 430)],
        "tail_pts": [("s", 262, 255, 320), ("s", 262, 320, 360), ("s", 262, 390, 395), ("s", 262, 470, 415)],
        "rigid": [("hand.R", (130, 232), (270, 405), (10, 215))], "rigid_no_guard": True,
    },
    "jacare_ladino": {
        "style": "melee2", "robe": False, "weapon": "R",
        "spine": [(262, 300), (262, 255), (262, 190), (262, 130), (265, 95)], "head_top": (265, 30),
        "arm.L": [(320, 140), (345, 210), (362, 270)], "hand_tip.L": (365, 290),
        "arm.R": [(205, 140), (180, 215), (160, 270)], "hand_tip.R": (150, 285),
        "leg.L": [(290, 320), (300, 390), (315, 450)], "leg.R": [(235, 320), (220, 390), (205, 450)],
        "tail_pts": [("s", 262, 225, 300), ("s", 262, 265, 345), ("s", 262, 330, 400), ("s", 262, 400, 430), ("s", 262, 475, 440)],
        "rigid": [("hand.R", (130, 215), (255, 345), None), ("hand.L", (338, 380), (255, 345), None)],
    },
    "cururu": {
        "style": "cast", "robe": True, "weapon": "R",
        "spine": [(260, 360), (260, 300), (260, 230), (260, 170), (260, 150)], "head_top": (260, 85),
        "arm.L": [(345, 205), (395, 240), (400, 190)], "hand_tip.L": (402, 175),
        "arm.R": [(180, 200), (140, 230), (112, 212)], "hand_tip.R": (105, 205),
        "leg.L": [(290, 400), (300, 440), (310, 470)], "leg.R": [(225, 400), (215, 440), (205, 470)],
        "rigid": [("hand.R", (75, 140), (20, 470), None)],
    },
    "perereca": {
        # the vine whip stays skinned (it is soft); the raised left hand leads the lash
        "style": "melee", "robe": False, "weapon": "L",
        "spine": [(258, 310), (258, 265), (258, 200), (258, 120), (258, 95)], "head_top": (258, 25),
        "arm.L": [(305, 150), (330, 190), (355, 150)], "hand_tip.L": (375, 100),
        "arm.R": [(200, 150), (150, 215), (135, 265)], "hand_tip.R": (140, 300),
        "leg.L": [(290, 320), (305, 390), (320, 460)], "leg.R": [(225, 320), (210, 390), (195, 460)],
    },
    # ---------------- boss2 ----------------
    # ("s", front_px, side_px, py) = point read on front (x) + side (y, z); ("t", top_px, top_py) = ground point on the top render
    "mapinguari": {
        "style": "melee2", "robe": False,
        "spine": [(256, 350), (256, 295), (256, 235), (258, 160), (262, 115)], "head_top": (262, 35),
        "arm.L": [(350, 175), (395, 265), (405, 345)], "hand_tip.L": (410, 420),
        "arm.R": [(165, 175), (120, 270), (115, 350)], "hand_tip.R": (110, 430),
        "leg.L": [(300, 370), (310, 420), (320, 470)], "leg.R": [(210, 370), (200, 420), (190, 470)],
    },
    "boitata": {
        # serpent: spine up the raised body, tail chain round the coil on the ground, no limbs
        "style": "bite", "robe": False, "die_style": "slump",
        "spine": [("s", 285, 190, 420), ("s", 262, 185, 340), ("s", 258, 200, 270), ("s", 255, 225, 190), ("s", 255, 200, 140)],
        "head_top": ("s", 255, 200, 40),
        "tail_pts": [("s", 285, 190, 420), ("t", 310, 320), ("t", 350, 250), ("t", 335, 175), ("t", 280, 140),
                     ("t", 215, 150), ("t", 175, 215), ("t", 185, 290)],
        "tail_axis": "Z", "tail_amp": 6,
    },
    "anhanga": {
        # quadruped deer: horizontal spine from the rump to the withers, front legs on the arm bones
        "style": "charge", "robe": True, "die_axis": "Y",
        "spine": [("s", 256, 305, 300), ("s", 256, 260, 290), ("s", 256, 215, 270), ("s", 256, 205, 215), ("s", 256, 185, 165)],
        "head_top": ("s", 256, 185, 60),
        "arm.L": [("s", 280, 215, 300), ("s", 280, 215, 380), ("s", 280, 220, 440)], "hand_tip.L": ("s", 280, 215, 475),
        "arm.R": [("s", 232, 215, 300), ("s", 232, 215, 380), ("s", 232, 220, 440)], "hand_tip.R": ("s", 232, 215, 475),
        "leg.L": [("s", 276, 320, 320), ("s", 276, 315, 400), ("s", 276, 320, 460)],
        "leg.R": [("s", 238, 300, 320), ("s", 238, 300, 400), ("s", 238, 300, 465)],
    },
    "cobra_grande": {
        # naga: human torso + serpent tail that drops to the ground and loops behind
        "style": "melee", "robe": False, "weapon": "R", "die_style": "slump",
        "spine": [(245, 300), (245, 260), (245, 200), (243, 150), (243, 125)], "head_top": (243, 85),
        "arm.L": [(300, 175), (330, 230), (335, 270)], "hand_tip.L": (332, 295),
        "arm.R": [(195, 180), (165, 210), (138, 215)], "hand_tip.R": (128, 215),
        "tail_pts": [(245, 300), ("s", 242, 182, 350), ("s", 235, 175, 415), ("t", 230, 330), ("t", 330, 275), ("t", 385, 200),
                     ("t", 340, 115), ("t", 250, 110), ("t", 175, 165), ("t", 150, 230), ("t", 205, 235), ("t", 215, 160), ("t", 150, 100)],
        "tail_axis": "Z", "tail_amp": 4,
        "rigid": [("hand.R", (100, 180), (20, 470), (110, 200))],
    },
    "mae_da_mata": {
        "style": "melee", "robe": False, "weapon": "R",
        "spine": [(290, 265), (290, 225), (290, 180), (290, 140), (290, 128)], "head_top": (290, 60),
        "arm.L": [(330, 150), (345, 205), (350, 260)], "hand_tip.L": (352, 290),
        "arm.R": [(250, 150), (215, 195), (182, 208)], "hand_tip.R": (172, 210),
        "leg.L": [(310, 290), (318, 375), (322, 455)], "leg.R": [(268, 290), (262, 375), (255, 455)],
        "rigid": [("hand.R", (145, 228), (15, 505), None)],
    },
}
