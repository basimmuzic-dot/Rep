extends Node
## Narrative content. Pure data, no logic.
##
## Case option kinds:  approve | review | decline  (Act I)
##                     investigate | accept | escalate (Act II)
## Every option converges on the same machinery: the system absorbs the choice.

const STYLES := {
	"pragmatist": {"name": "THE PRAGMATIST", "blurb": "Results matter. Good intentions feed no one."},
	"idealist": {"name": "THE IDEALIST", "blurb": "Systems can be changed from the inside. Someone has to try."},
	"cynic": {"name": "THE CYNIC", "blurb": "You assume the worst. You still can't stop it."},
}

# Per-style starting dissonance and how fast guilt accumulates.
const STYLE_RATE := {"pragmatist": 1.0, "idealist": 1.25, "cynic": 0.85}
const STYLE_START := {"pragmatist": 4, "idealist": 0, "cynic": 14}

const ACT_TITLES := {
	1: ["ACT I", "The Mundane"],
	2: ["ACT II", "Fragments"],
	3: ["ACT III", "Authorization 77-K"],
}

const CASES := [
	# ───────────────────────── ACT I ─────────────────────────
	{
		"id": "water", "act": 1, "from": "Regional Desk, Kessara",
		"title": "Loan 0412 · Kessara North Water Project",
		"body": "The village council of Kessara North asks for a $2M low-interest loan to dig wells and lay pipe. Three hundred families currently walk two hours for water. Their proposal is meticulous; someone has clearly sat up late over it.",
		"fine": "Sec. 14.7 — If the project \"experiences material delay,\" mineral and land-use rights revert to the Lender.",
		"msg": ["Amara", "Dear friend at Concord — the children drew you a picture. It is mostly a well, and a very large smiling man in a tie. That is you. Thank you for listening."],
		"helped": 12000,
		"options": [
			{"k": "approve", "label": "Approve as submitted", "dis": 2,
			 "res": "Approved. The system chimes. Somewhere, a backhoe is being scheduled."},
			{"k": "review", "label": "Send the fine print to Legal", "dis": 6,
			 "res": "Legal answers in four minutes: standard language, used in every Concord loan. You approve with a note in the margin. The note is archived. Nobody reads archives."},
			{"k": "decline", "label": "Decline until terms improve", "dis": 4,
			 "res": "Your decline is overturned by the Regional Director before lunch. The loan proceeds under his name. The ticker still credits the quarter."},
		],
	},
	{
		"id": "clinic", "act": 1, "from": "Health Logistics",
		"title": "Shipment 88 · Kessara Central Clinic",
		"body": "One container of pharmaceuticals and diagnostic equipment for a clinic serving thirty thousand people. At present the clinic runs on a handful of nurses, a midwife network, and herbal remedies. Our equipment will modernize everything.",
		"fine": "Appx. C — Equipment is leased, not donated. Consumables available exclusively from Concord Health Supply.",
		"msg": ["Dr. Teo", "Your shipment manifest reached us. I have never held a working ultrasound! Between us, the old midwives are grumbling. Pride is a heavy thing. I told them a good tool is a good tool."],
		"helped": 30000,
		"options": [
			{"k": "approve", "label": "Approve shipment", "dis": 2,
			 "res": "Approved. By Friday the clinic has a machine that can see a heartbeat. By next spring it will have no one who knows how to work without it."},
			{"k": "review", "label": "Request a dependency study", "dis": 6,
			 "res": "The study returns: \"Moderate sustainability risk, mitigable through long-term partnership.\" Long-term partnership is another word for the contract you are about to sign."},
			{"k": "decline", "label": "Decline", "dis": 4,
			 "res": "Declined. The shipment is rerouted through the Provincial Health Office, which marks it up fourfold. The clinic receives it anyway, eight months late and on worse terms."},
		],
	},
	{
		"id": "roads", "act": 1, "from": "Infrastructure Partnerships",
		"title": "Contract 17 · Regional Roads and Power",
		"body": "The Provincial Authority requests $5M for roads, power lines and a market hall. The Governor is a longtime partner of Concord, warm on calls, generous with local hospitality. The bidding firms are all \"regionally owned.\"",
		"fine": "Bidder registry — Four of five bidders list the Governor's brother-in-law as a director.",
		"msg": ["Jun", "hi!! my goat had twins!!! I named them Loan and Interest, as a joke Teacher told me about. is that a joke? she laughed a weird way. anyway when the road comes my uncle says the goat cheese can go to the city."],
		"helped": 41000,
		"options": [
			{"k": "approve", "label": "Sign the contract", "dis": 3,
			 "res": "Signed. The Governor sends a handwritten thank-you note and a case of excellent coffee. You drink it for weeks."},
			{"k": "review", "label": "Request a bidder audit", "dis": 7,
			 "res": "The audit confirms all bidders are \"independent.\" The Governor is wounded by the suggestion and sends flowers to apologize for the inconvenience. The contract proceeds."},
			{"k": "decline", "label": "Decline", "dis": 4,
			 "res": "The Governor calls your Director personally. Your decline is reclassified as a clerical hold, then released. He is gracious about it."},
		],
	},
	{
		"id": "school", "act": 1, "from": "Education Fund",
		"title": "Grant 211 · Northern Schools Initiative",
		"body": "Three new schools and teacher training for a region with thirty-five percent literacy. The materials arrive in glossy folders, pre-translated, with a branded curriculum called Concord Pathways. The teachers are thrilled to have anything at all.",
		"fine": "Pathways Unit 4: \"Debt Is a Partnership.\" Unit 7: \"Why Resource Agreements Protect Families.\"",
		"msg": ["Amara", "The new textbooks are beautiful. Full colour! Unit 4 is about debt. I did not know debt had a unit, but I suppose everything does. The children are learning fast. I am proud of them."],
		"helped": 18000,
		"options": [
			{"k": "approve", "label": "Approve the grant", "dis": 2,
			 "res": "Approved. A generation will learn to read from your folders."},
			{"k": "review", "label": "Review the curriculum", "dis": 6,
			 "res": "Curriculum Review notes \"alignment with partner values.\" They suggest it be called a feature. You tag the file as a feature."},
			{"k": "decline", "label": "Decline", "dis": 4,
			 "res": "Declined. The schools are funded by the Regional Authority instead, with the same folders, and a worse teacher-training budget."},
		],
	},
	{
		"id": "seed", "act": 1, "from": "Agricultural Division",
		"title": "Program 56 · Farming Cooperative Partnership",
		"body": "Improved seed, fertilizer and training for the northern cooperatives, who have asked for it by name. Projected yields rise forty percent. The Agricultural Division has surplus inventory it would like to move before the season turns.",
		"fine": "Seed license — Harvested seed may not be saved or replanted. Licensed per season.",
		"msg": ["Jun", "dad says the new seeds are very good but you have to buy them every year, even though a seed is literally a seed. he laughed about it. then he stopped laughing. is it still a joke."],
		"helped": 26000,
		"options": [
			{"k": "approve", "label": "Approve the program", "dis": 2,
			 "res": "Approved. The first harvest is spectacular. You are sent a photo; the field is the exact green of a banknote."},
			{"k": "review", "label": "Review seed terms", "dis": 6,
			 "res": "Legal confirms the license is lawful, \"industry standard,\" and \"in the farmers' interest as an innovation incentive.\" You approve with a feeling you decide not to name."},
			{"k": "decline", "label": "Decline", "dis": 4,
			 "res": "Declined. A rival conglomerate quietly buys the same cooperatives the following month, with a harsher license."},
		],
	},
	{
		"id": "credit", "act": 1, "from": "Microfinance",
		"title": "Facility 33 · Women's Cooperative Credit",
		"body": "A revolving credit pool for market women in the Kessara highlands. Small loans, quick repayment, group guarantees. Last quarter's brochure used a photograph of one of them laughing. They looked happy. They may have been.",
		"fine": "Collateral — Land deeds held in escrow. Interest compounds on default, and defaults are cross-guaranteed across the group.",
		"msg": ["Dr. Teo", "Three women came in this week with the same complaint: they cannot sleep. I gave them what I had. It was not medicine they needed. I do not know what to call what they need."],
		"helped": 9000,
		"options": [
			{"k": "approve", "label": "Approve the facility", "dis": 2,
			 "res": "Approved. The first month's repayment rate is 99.1%. Your Director forwards the number to the board with three exclamation marks."},
			{"k": "review", "label": "Query the collateral terms", "dis": 6,
			 "res": "Underwriting explains that \"group guarantees are the mechanism of financial inclusion.\" You are thanked for your diligence and invited to speak at a conference."},
			{"k": "decline", "label": "Decline", "dis": 4,
			 "res": "Declined. The women borrow from a private lender instead, at terms that would make Concord blush, if Concord could."},
		],
	},
	# ───────────────────────── ACT II ─────────────────────────
	{
		"id": "famine", "act": 2, "from": "Field Report · Unverified",
		"title": "Report · Kessara North, Hunger Season",
		"body": "A field coordinator writes that three villages are in famine. The wells you funded are working, but the harvest failed and the loan fell into default. Under the land-option clause, fields were repossessed and \"consolidated.\" Children are being fed from Concord relief packages.",
		"fine": "Talking points memo: \"Seasonal food insecurity is a regional constant, unrelated to financing arrangements.\"",
		"msg": ["Amara", "The school has fewer children each week. Their parents have left to look for work in the city. I stand at the board and talk to desks. I am not angry. I want you to know I am not angry."],
		"helped": 0,
		"options": [
			{"k": "investigate", "label": "Pull the loan records", "dis": 14,
			 "res": "Every repossessed field was on your approval chain. The date stamps are in sequence. You can see the exact afternoon each family lost its land. It was the afternoon you were pleased with yourself."},
			{"k": "accept", "label": "Accept the talking points", "dis": 3,
			 "res": "Seasonal. It is a reasonable word. You file the report under unverified and feel something loosen in your chest."},
			{"k": "escalate", "label": "Escalate to Ethics", "dis": 8,
			 "res": "Ethics acknowledges receipt automatically. The ticket is closed in six minutes with the resolution code ALIGNED. You do not know what it was aligned to."},
		],
	},
	{
		"id": "trial", "act": 2, "from": "Clinic Staff · Anonymous",
		"title": "Report · Central Clinic, Unconsented Trial",
		"body": "A nurse writes that a new contraceptive-adjacent compound, supplied under the Concord health shipment, is being administered to women as a \"free vitamin injection.\" No consent forms. Staff report a pattern of complications and permanent infertility.",
		"fine": "Phase III Compliance memo: \"Observational data. Local clinics do not meet reporting standards for adverse events.\"",
		"msg": ["Dr. Teo", "I am writing from my sister's phone. I cannot say much. If I stop writing, please do not assume anything. Please assume everything. Do you understand? I think you understand."],
		"helped": 0,
		"options": [
			{"k": "investigate", "label": "Request the trial protocol", "dis": 14,
			 "res": "The protocol exists, signed three days after your shipment approval. The consent section reads \"to be addressed locally.\" It was addressed locally. The nurse who addressed it is named in the file."},
			{"k": "accept", "label": "Accept the compliance memo", "dis": 3,
			 "res": "Observational data. Reporting standards. The words are professional, and professionalism is a kind of warmth. You close the tab gently, as if it might wake."},
			{"k": "escalate", "label": "Escalate to Ethics", "dis": 8,
			 "res": "Ethics confirms the matter is under review by the same department running the study. You are thanked for your vigilance."},
		],
	},
	{
		"id": "memo", "act": 2, "from": "Leaked Document",
		"title": "Leaked Memo · Dray, Civil Society",
		"body": "An activist's memo, forwarded without comment. It alleges Concord funded and advised the Provincial Guard when it dissolved Kessara's elected council, to guarantee the resource contracts. It includes wire references. Corporate Communications has already called it \"a forgery by a known agitator.\"",
		"fine": "Wire ref KPG-2291 — Counterparty: Provincial Guard Logistics. Approver: Regional Director. Cost center: Development Outreach.",
		"msg": ["Jun", "uncle says the soldiers came and the council is gone. he says we have to be quiet now. I am being quiet. I am telling the goats. is that okay?"],
		"helped": 0,
		"options": [
			{"k": "investigate", "label": "Trace the wire reference", "dis": 14,
			 "res": "The cost center is the one that paid for your Q2 team retreat. The wire sits three lines above the catering invoice. You know the name of the hotel."},
			{"k": "accept", "label": "Accept the Communications statement", "dis": 3,
			 "res": "A known agitator. You write the phrase twice, to see if it sticks. It sticks. That is the unsettling part."},
			{"k": "escalate", "label": "Escalate to Ethics", "dis": 8,
			 "res": "Ethics replies that the matter is outside its scope, as the funds were classified as Outreach. You are thanked for your engagement."},
		],
	},
	{
		"id": "lantern", "act": 2, "from": "Colleague · Hollis",
		"title": "File · Project LANTERN",
		"body": "A colleague slides a thin file onto your desk and leaves without a word. LANTERN is a ten-year plan: loans, shipments, contracts and grants, sequenced by a model that predicts which villages will default, which clinics will fold, which councils will bend. Your approvals are in the appendix. You were not meant to be the author. You were meant to be the instrument.",
		"fine": "Appendix F — \"Officer discretion: modeled as noise. No material effect on outcomes.\"",
		"msg": ["Amara", "Teo has not written in nine days. The clinic is shut. Someone says soldiers, someone says a fever. The children ask me why I look at the window. I told them I am waiting for a delivery."],
		"helped": 0,
		"options": [
			{"k": "investigate", "label": "Read the whole appendix", "dis": 16,
			 "res": "Officer discretion: modeled as noise. You flip back through your decisions and see that even the ones you refused were in the model. You were never choosing. You were being forecast."},
			{"k": "accept", "label": "Treat it as confidential strategy", "dis": 3,
			 "res": "A growth plan. Of course there is a growth plan. You put it in the drawer, where it hums."},
			{"k": "escalate", "label": "Return it to Hollis", "dis": 8,
			 "res": "Hollis smiles with a tenderness you did not expect. \"You've been good for the region,\" he says, and you realize it is the kindest thing anyone has said to you in a year."},
		],
	},
	{
		"id": "marek", "act": 2, "from": "Compliance · Marek V.",
		"title": "Private Call · Marek V., Compliance",
		"body": "A man from Compliance asks to meet in the stairwell. He has been copying documents for a year. He will go public with everything: the clauses, the trial, the wires, LANTERN. He needs one thing: a record of your approvals, the ones with your name on them. Without them he has a story. With them he has a case.\n\nHe says: \"I'm not asking you to be brave. I'm asking you to be present.\"",
		"fine": "Marek, at the end of the call: \"They will offer you something before I publish. Look at what it costs.\"",
		"msg": ["Dr. Teo", "If this message arrives, the one on my sister's phone worked. Tell the children at Amara's school the nurse says hello. Tell Jun to keep naming the goats. I am not afraid. I wish I could say I was."],
		"helped": 0,
		"options": [
			{"k": "investigate", "label": "Give him your records", "dis": 14,
			 "res": "He thanks you. His voice is very steady. You understand that he has been steady for a year so that someone else could afford not to be."},
			{"k": "accept", "label": "Say you will think about it", "dis": 4,
			 "res": "You say that you will think about it. He nods like a man who knows what the thinking will become. He writes his number on a napkin. You keep the napkin."},
			{"k": "escalate", "label": "Report the approach to Security", "dis": 10,
			 "res": "Security thanks you for your loyalty. You are walked back to your desk with a courtesy you did not ask for. There is a new plant on it."},
		],
	},
]

# ───────────────────────── ACT III ─────────────────────────
const FINAL := {
	"title": "Authorization 77-K",
	"body": "The offer arrives on your desk as an elegant, short document. It retroactively ratifies every loan, shipment and contract with your name on it as \"compliant with all applicable standards,\" and consolidates Concord's authority over Kessara for another decade. Marek publishes tomorrow either way.\n\nIf you sign, the past is sealed and the region is managed. If you refuse, Marek's leak will bring the board down on the aid wing, and the aid wing is how most of Kessara eats. If you leak your own records first, Security will find you before the morning.\n\nThere is no fourth option. There is a pen.",
	"options": [
		{"k": "sign", "label": "Sign 77-K"},
		{"k": "refuse", "label": "Refuse, and let Marek publish"},
		{"k": "leak", "label": "Leak everything yourself, tonight"},
	],
}

# Last messages from the pen pals, per route.
const LAST_MESSAGES := {
	"sign": {
		"Amara": "Dear friend. The school has reopened under the new Pathways. All the children are here, and no one looks out the window. Letters now go through the Regional Desk, so I will keep this short and happy. We are well. We are grateful. We are well.",
		"Dr. Teo": "[no message. Status: reassigned, location restricted.]",
		"Jun": "hi!! the new dam is so big. uncle says our valley will be under it by spring. the goats are going to a farm somewhere. I am not sure how I know they are not. please say hi to Loan and Interest for me",
	},
	"refuse": {
		"Amara": "The school has closed. Concord is gone, and with it the teachers, the books, the bread. I am boiling what we have. I am not angry. I want you to know I understand why you did what you did.",
		"Dr. Teo": "Supplies ran out Thursday. We have the machine and nothing to put into it. An ultrasound is just a very polite mirror. I am staying.",
		"Jun": "we are walking to the border. dad has the goats on a rope. I am typing on a stranger's phone. if you get this please tell me it was worth it. I want it to have been worth it. I am eleven.",
	},
	"leak": {
		"Amara": "They say you disappeared. I have hidden your picture, the one the children drew, inside the school stove. The warlords took the roof. I am teaching from the doorway. We are learning the names of the stars.",
		"Dr. Teo": "[no message. The clinic was burned on the third night. Staff list unaccounted.]",
		"Jun": "[photo attached: a goat, looking out the back window of a bus. No text.]",
	},
}

const ENDINGS := {
	"sign": {
		"title": "THE PROMOTION",
		"text": "You are promoted. The ceremony has a cake, and the cake has your name on it in blue icing.\n\nThe quarterly film is cheerful. The region is described as \"stabilized.\" There are drone shots of the long straight roads, and for three seconds a woman at a market stall, smiling, who may have been anyone.\n\nOn your desk is a framed drawing: a very large man in a tie standing beside a well. You turn it to face the wall. Then you turn it back, because you cannot stand to not look.\n\nLetters from Kessara keep arriving, but they have begun to sound alike. They are polite. They are grateful. They have been edited.",
	},
	"refuse": {
		"title": "THE SCAPEGOAT",
		"text": "Marek's leak is complete and then, within a week, it is wrong. The version that spreads leaves out the clauses, the trial, the wires. It keeps your name.\n\nConcord announces an independent review, which finds a mid-level administrator who misused his discretion. The board resigns with generous severance. The aid wing is dissolved \"to prevent recurrence.\" You are the recurrence.\n\nYou live under another name in another country, and you scroll through memorial pages late at night. You recognize some of the faces. You recognize them from photographs they sent you with the message: thank you for listening.",
	},
	"leak": {
		"title": "THE DISAPPEARANCE",
		"text": "Security finds you at dawn. There is no violence. There is a car, and a room, and a long period during which no one tells you anything.\n\nYears later you are released in a prisoner exchange, thin and quiet, onto a runway under a cold sky. The region you tried to warn has become a failed state governed by arms dealers, and the documentaries about it are very well made.\n\nIn your sparse apartment you watch them, one after another. Narrators explain how it happened. They all say the same thing. No one mentions you, and you can't decide whether that is mercy.",
	},
}

const CODA := "You did not fail because you were evil. You failed because the system took your care and used it as a tool. Your good intentions were the mechanism of harm."

# ───────────────────────── Narration ─────────────────────────
# Phase 0 = confident, 1 = cracks, 2 = aware.
const NARRATOR := {
	"pragmatist": [
		["Real people, real water. The paperwork is just how good things get done.",
		 "The numbers are good. I don't need to feel good about them; I need them to be good."],
		["If I hadn't signed, someone worse would have. That's not an excuse. That's arithmetic.",
		 "Every system has friction. That does not make the system the enemy."],
		["Arithmetic. I keep saying that word. It stopped meaning anything a few files ago.",
		 "I used to think a good outcome was a number. I can't find the number that includes them."],
	],
	"idealist": [
		["I am helping. I can feel it in my hands. That is a real thing.",
		 "This is how change happens: someone inside, doing a little more than they must."],
		["There are problems, yes. But problems are what I'm here to fix. I'll fix them next quarter.",
		 "If I leave, the next person won't care. I have to stay. I have to."],
		["I thought being inside would make me an inside voice. I was only ever inside.",
		 "I told myself I was bending the system. It was bending me. I called it growth."],
	],
	"cynic": [
		["I know how these places work. I'm not surprised. Being unsurprised is not the same as being innocent.",
		 "Everyone's got an angle. At least I'm honest about mine."],
		["I told myself I'd seen it coming. I did. That didn't help anyone.",
		 "Cynicism is just guilt that has learned to shrug."],
		["I saw it coming. I filed it anyway. What does it mean to see something and sign it?",
		 "I wanted to be the one who knew. I did not want to be the one who did."],
	],
}

# Colleagues you can talk to. Lines per phase 0/1/2.
const COLLEAGUES := {
	"Dana": {"role": "Director of Impact Storytelling", "color": Color(0.85, 0.35, 0.30), "lines": [
		["Have you seen the new numbers? We crossed fifty thousand lives. FIFTY. Thousand. I'm going to cry in the elevator.",
		 "We're not a company, we're a movement with a very good dental plan."],
		["Fifty thousand. Sixty. I've stopped counting; the dashboard counts for me. Is that a bad sign?",
		 "Do you ever feel like the photographs are getting younger? I think I'm approving younger photographs."],
		["I used to write stories. Now I edit them. There's a difference and I stopped looking for it.",
		 "If you hear me laughing at the printer, don't come check on me."],
	]},
	"Pritch": {"role": "Junior Analyst, Regional Desk", "color": Color(0.30, 0.55, 0.85), "lines": [
		["First week! Everyone's so nice. Is it normal that the break room has a fountain? Like a real fountain?",
		 "They told me we're helping villages. I have a spreadsheet of villages. They look so tidy in a spreadsheet."],
		["I keep finding the same words in the contracts. 'Material delay.' 'Aligned.' They are not words, they are handles.",
		 "I asked a question in the meeting and Hollis wrote it down. He wrote it down so kindly. I haven't been asked anything since."],
		["I am training the model on you, you know. Your approvals. Do you want me to stop? I can't stop. Do you want me to?",
		 "I don't have any questions anymore. Isn't that wonderful?"],
	]},
	"Sol": {"role": "Senior Underwriter", "color": Color(0.60, 0.50, 0.30), "lines": [
		["Take it from a veteran: you can't save the world. You can save a quarter. Save the quarter.",
		 "The trick is not to read the fine print. The fine print is for the other side."],
		["I read the fine print once. In '09. It gave me a good decade of drinking.",
		 "You've got the look. You've started to read it. Stop reading it. It doesn't change anything and it ruins your sleep."],
		["You do know that none of us is good, right? I mean no one. That's the point of a good system.",
		 "Whatever you decide, do it fast. The not-deciding is the worst part. I would know."],
	]},
	"Hollis": {"role": "Regional Director", "color": Color(0.35, 0.35, 0.40), "lines": [
		["You're doing wonderful work. Wonderful. I tell the board your name.",
		 "I know it's not easy, caring this much. The world needs more people who care this much."],
		["I've noticed you've been pulling a lot of files lately. That's wonderful. Curiosity is a corporate value.",
		 "You and I are the same, you know. We care. The caring is why they let us stay."],
		["You've been good for the region. I want you to hear that. Whatever else happens, hear that.",
		 "I wonder what it would feel like to be told I'd done something wrong. I think I'd be relieved."],
	]},
}

# Posters: arrays of three phrasing phases. {n} is replaced with lives helped.
const POSTERS := [
	["IMPACT\n{n} LIVES HELPED", "IMPACT\n{n} LIVES HELD", "EXTRACTION\n{n} ACCOUNTS ACQUIRED"],
	["PARTNERSHIP\nIS OUR PROMISE", "PARTNERSHIP\nIS OUR TERMS", "DEPENDENCE\nIS OUR PRODUCT"],
	["LISTEN.  LEARN.  LEAD.", "LISTEN.  LEARN.  LEASE.", "LISTEN.  LOG.  LIQUIDATE."],
	["WE ARE\nALL IN THIS TOGETHER", "WE ARE\nALL IN THIS", "WE ARE\nALL IN."],
]

const WINDOW_NOTES := [
	"The city is lit and orderly. Somewhere beyond it, a country you have never visited is waiting for your signature.",
	"The skyline looks the same. You are the thing that has changed, and you are not sure when.",
	"The city glass is a mirror now. You can see the office, and one tired administrator in it.",
]
