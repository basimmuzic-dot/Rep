extends Node
## Pure data container for all narrative content

const ACTS = {
	1: {
		"cases": [
			{
				"id": "loan_1",
				"title": "Loan Application: Kessara North Water Project",
				"body": "The village council in Kessara North seeks a $2M loan to develop water infrastructure. Their proposal is thorough. Our preliminary assessment shows the land is fertile; development could expand significantly. [Fine print mentions a land-option clause giving us mineral extraction rights if project fails.]",
				"choices": ["Approve", "Request Full Review", "Decline"],
				"approving_text": "Loan approved. Villages will have clean water for years.",
				"investigating_text": "You review the fine print. The extraction clause is buried in subsection 14.7. If the project faces any difficulty, we can seize land for mining operations.",
				"correct_choice": "Request Full Review",
				"impact": "helped",
				"dissonance_delta": [5, 0, 15],
			},
			{
				"id": "healthcare_1",
				"title": "Medical Shipment: Kessara Central Clinic",
				"body": "Request to send a containerload of pharmaceutical supplies and diagnostic equipment to the clinic serving 30,000 people in Kessara Central. The clinic currently uses traditional herbal medicine and midwifery. Our equipment and drugs will modernize care.",
				"choices": ["Approve Shipment", "Request Environmental Study", "Decline"],
				"approving_text": "Shipment approved. The clinic will save countless lives with modern medicine.",
				"investigating_text": "The environmental study reveals a risk: the clinic will become dependent on supply chains we control. Local practitioners have been displaced in similar rollouts. Within 5 years, if we withdraw, the clinic has no one to run it.",
				"correct_choice": "Request Environmental Study",
				"impact": "helped",
				"dissonance_delta": [8, 2, 18],
			},
			{
				"id": "development_1",
				"title": "Infrastructure Development: Kessara Regional Authority",
				"body": "The Regional Authority has requested $5M to build roads, power lines, and market facilities. This will open the region to commerce. The Authority is led by the Provincial Governor, a longtime partner.",
				"choices": ["Approve Contract", "Audit Leadership", "Decline"],
				"approving_text": "Development contract signed. The roads will transform the region's economy.",
				"investigating_text": "An audit reveals the Governor and his family own 60% of the companies bidding on the project. The 'development' primarily benefits the elite; the benefit to ordinary people is negligible.",
				"correct_choice": "Audit Leadership",
				"impact": "helped",
				"dissonance_delta": [10, 3, 20],
			},
			{
				"id": "school_grant",
				"title": "Educational Grant: North Kessara Schools",
				"body": "Request for $800K to build three schools and supply materials. Current literacy rate is 35%. The proposal includes teacher training.",
				"choices": ["Approve Grant", "Verify Curriculum", "Decline"],
				"approving_text": "Grant approved. A generation of children will now have access to education.",
				"investigating_text": "Curriculum review shows the materials focus heavily on corporate branding and 'partnership' themes. The school will teach children to see Meridian Concord as their savior.",
				"correct_choice": "Verify Curriculum",
				"impact": "helped",
				"dissonance_delta": [7, 1, 16],
			},
			{
				"id": "agricultural_tech",
				"title": "Agricultural Technology Transfer: Kessara Farming Cooperatives",
				"body": "Cooperatives request seeds, fertilizers, and training in modern farming. They promise to increase yields significantly. Our agricultural division has surplus inventory.",
				"choices": ["Approve Program", "Review Seed Terms", "Decline"],
				"approving_text": "Program approved. Farmers will produce more food, reducing hunger.",
				"investigating_text": "The seed contract requires replanting new seeds each year; farmers cannot replant their own harvest. They become locked into purchasing from us annually.",
				"correct_choice": "Review Seed Terms",
				"impact": "helped",
				"dissonance_delta": [9, 2, 17],
			},
			{
				"id": "microfinance",
				"title": "Microfinance Initiative: Kessara Women's Entrepreneur Collective",
				"body": "Women's collective requests small business loans at favorable rates to start shops and services. Projected to generate 500 jobs.",
				"choices": ["Approve Initiative", "Check Interest Rates", "Decline"],
				"approving_text": "Initiative approved. Women will gain economic independence.",
				"investigating_text": "The 'favorable' 12% interest rate is actually predatory in a region where traditional lending is 3%. Many borrowers will default within 3 years.",
				"correct_choice": "Check Interest Rates",
				"impact": "helped",
				"dissonance_delta": [6, 0, 14],
			},
		]
	},
	2: {
		"cases": [
			{
				"id": "famine_report",
				"title": "Field Report: Famine in Northern Villages",
				"body": "A report from our field team indicates severe crop failure in the three villages that received the water project loan. Food is scarce. The report speculates it may be due to contamination of the irrigation system. They request authorization to send emergency food aid.",
				"choices": ["[Investigate]", "[Accept Talking Points]"],
				"approving_text": "You rationalize: crop failures happen. We can send aid. We're not responsible for weather.",
				"investigating_text": "Investigation reveals the contamination was caused by our mineral extraction operations upstream. The extraction began after the water project had issues, triggering the extraction clause. We poisoned the water to open mining.",
				"correct_choice": "[Investigate]",
				"impact": "investigated",
				"dissonance_delta": [12, 25],
			},
			{
				"id": "clinic_incident",
				"title": "Internal Memo: Clinic Complications",
				"body": "A clinic director reports unexpected complications. Women receiving our medications for routine care are experiencing unexplained infertility. The memo notes this is a 'minor setback' and requests guidance.",
				"choices": ["[Investigate]", "[Accept Talking Points]"],
				"approving_text": "You write back: 'Monitor situation, report monthly. Do not alarm patients.'",
				"investigating_text": "Deeper investigation: the pharmaceutical batch was an expired trial drug never approved for human use. The clinic director knew. Our team approved the shipment knowing it was surplus trial stock.",
				"correct_choice": "[Investigate]",
				"impact": "investigated",
				"dissonance_delta": [15, 30],
			},
			{
				"id": "activist_memo",
				"title": "Leaked Document: Activist Coalition Analysis",
				"body": "A memo surfaces from a regional activist group. It details a series of observations: villagers dislocated by our development projects, the Regional Governor's enrichment, the school curriculum's propaganda. The memo concludes: 'Meridian Concord is consolidating control of Kessara for economic extraction.'",
				"choices": ["[Investigate]", "[Accept Talking Points]"],
				"approving_text": "You dismiss it as exaggeration. Activists always inflate problems. Our intentions are good.",
				"investigating_text": "You read the entire memo. Every claim is documented with specific examples, interviews, and financial records. The pattern is undeniable. You realize you've been executing the exact blueprint described.",
				"correct_choice": "[Investigate]",
				"impact": "investigated",
				"dissonance_delta": [20, 35],
			},
			{
				"id": "power_struggle",
				"title": "Intelligence Report: Political Coup Planned",
				"body": "An intelligence report warns of an imminent coup attempt. The Regional Governor (our development partner) is funding private militia with money from the infrastructure project. He plans to consolidate power. Our headquarters suggests we publicly withdraw support and distance ourselves.",
				"choices": ["[Investigate]", "[Accept Talking Points]"],
				"approving_text": "You draft a statement withdrawing support. Meridian Concord values democracy.",
				"investigating_text": "Deeper digging: Meridian's leadership anticipated this. We funded the development project KNOWING it would enable this coup. The chaos that follows will allow us to acquire land at pennies on the dollar.",
				"correct_choice": "[Investigate]",
				"impact": "investigated",
				"dissonance_delta": [18, 32],
			},
			{
				"id": "whistleblower",
				"title": "Anonymous Tip: Corruption Within",
				"body": "An anonymous whistleblower sends evidence that our regional team has been embezzling from aid budgets. The evidence is solid. A decision is needed: investigation or quiet settlement.",
				"choices": ["[Investigate]", "[Accept Talking Points]"],
				"approving_text": "You recommend a quiet settlement with the team member. Public scandal helps no one.",
				"investigating_text": "Full investigation reveals the embezzlement was systematic, approved at middle management. But also: this person has documentation that Meridian HQ knew about every scheme we've been approving. They're being offered hush money and exile.",
				"correct_choice": "[Investigate]",
				"impact": "investigated",
				"dissonance_delta": [17, 33],
			},
		]
	},
	3: {
		"cases": [
			{
				"id": "final_authorization",
				"title": "Final Authorization: Meridian's Strategic Expansion",
				"body": "Headquarters requests final sign-off on Project Meridian: a plan to formalize control of Kessara's water, food supply, and political system through a series of strategic acquisitions, using our humanitarian projects as cover. The region will become a 'corporate development zone.' Implementation will silence critics and consolidate power. Your three choices:",
				"choices": ["SIGN THE AUTHORIZATION", "REFUSE THE AUTHORIZATION", "LEAK THE DOCUMENTS"],
				"approving_text": "",
				"investigating_text": "",
				"correct_choice": "REFUSE THE AUTHORIZATION",
				"impact": "final_choice",
				"pen_pal_outcomes": {
					"SIGN THE AUTHORIZATION": ["silenced", "silenced", "alive"],
					"REFUSE THE AUTHORIZATION": ["alive", "alive", "silenced"],
					"LEAK THE DOCUMENTS": ["alive", "alive", "silenced"],
				},
				"dissonance_delta": [50, 50, 50],
			},
		]
	},
}

const PEN_PALS = {
	"Amara": {
		"region": "Kessara North",
		"role": "Primary School Teacher",
		"initial_message": "Hello! I'm Amara, a teacher at North Kessara Primary. I wanted to thank you personally for approving the school grant. The children have new materials and hope. Thank you for caring about our future.",
		"messages": [
			"The curriculum arrived. It's beautiful. But I notice... it seems to emphasize Meridian Concord rather a lot. Is this normal?",
			"Some children are asking if Meridian Concord is our country now. I don't know how to answer. Are we becoming dependent on you?",
			"Three of my students' families have been dislocated by the infrastructure project. They're moving to the city. What happened to development?",
			"I received a letter offering me a job at Meridian's corporate education program. Better pay. But it would mean leaving the village. I don't know what to do.",
			"I'm closing my school. The regional authority has transferred our land for a development project. I'm moving away.",
		]
	},
	"Dr. Teo": {
		"region": "Kessara Central",
		"role": "Clinic Nurse",
		"initial_message": "Dr. Teo here. Thank you for the medical shipment. The equipment is remarkable. My team is learning to use it. The patients are grateful.",
		"messages": [
			"Something is wrong. Women receiving the new medications are getting sick. I'm documenting everything, but I'm frightened. What if this is our fault?",
			"I confronted my director about the medications. He told me to stay quiet. He seemed scared. I think he knew.",
			"The medications came from a trial program that was never approved. Our director bought the surplus. We've been testing experimental drugs on our patients without consent.",
			"I'm trying to blow the whistle, but I'm afraid. Meridian has made it clear that speaking out will destroy my career. They own the clinic.",
			"I left. I took jobs at three different clinics under assumed names. I'm hiding. I'm sorry I couldn't stay and help you see the truth sooner.",
		]
	},
	"Jun": {
		"region": "Kessara North",
		"role": "Teenager, Goat Farmer",
		"initial_message": "Hi! I'm Jun. I help my family with our goats. I heard we got a water project! That's exciting. My goats will have better water to drink. Thanks!",
		"messages": [
			"The new seeds are amazing! Our crops are bigger than ever. My family is making real money now. I'm going to be able to go to the school you funded!",
			"Wait. What's happening? My family has to buy new seeds every year now? We can't replant our own harvest? The costs are going up. Dad is worried.",
			"Dad lost the farm. We couldn't afford the seeds. We sold everything to the Regional Authority for almost nothing. They're turning it into some kind of mining operation?",
			"I'm in the city now. Working in a factory. I miss my goats. I miss the land. I miss home. This wasn't supposed to happen.",
			"I read the documents you leaked. The activist memo was right about everything. Why did it take you so long? My whole region is ruined.",
		]
	},
}

const ENDINGS = {
	"sign": {
		"title": "PROMOTION",
		"epilogue": "Six months later, you're promoted to Vice President of Regional Operations. The office in Kessara City is palatial. The ticker counts 500,000 lives improved. The photos on your desk show the Regional Governor cutting ribbons at ceremonies. Meridian Concord's flag flies over the water treatment plants, schools, and hospitals. You receive occasional updates from the field: productivity is up. Opposition has been 'managed.' You don't read the longer reports. There's a framed photo on your desk of you at the groundbreaking for the water project. You look happy. You rarely touch it.",
		"message_label": "ENDING: YOU SIGNED THE AUTHORIZATION"
	},
	"refuse": {
		"title": "EXILE",
		"epilogue": "You refused the authorization and Meridian fired you immediately. Corporate security locked you out of the building. Your name was leaked to the press as a 'disgruntled employee spreading lies.' By evening, activist groups claimed you as a whistleblower. By next morning, Meridian's lawyers demanded you sign an NDA, threatening to destroy your career. You signed. You couldn't talk. But someone leaked the documents anyway—the full blueprint. The story broke globally. Meridian faced investigations. But in Kessara, the regime you warned of was already taking hold. The Regional Governor's militia consolidated power. You were blamed. Activists who had wanted to trust you felt betrayed for not leaking the documents yourself. You live in a small apartment in another country, unable to return home, unable to speak. You watch documentaries about Kessara. In one, a survivor describes the regime's rise. You recognize the path you tried to stop.",
		"message_label": "ENDING: YOU REFUSED THE AUTHORIZATION"
	},
	"leak": {
		"title": "DISAPPEARED",
		"epilogue": "You copied everything and sent it to journalists and activist groups. Then you walked into Meridian's lobby and confessed. Security held you while lawyers arrived. You spent three years in a detention facility in Kessara—technically a 'holding area' for people of interest. The regime had taken control and saw you as a threat. You were tortured with questions about who helped you leak. You didn't talk. After two thousand days, there was a prisoner exchange. You were traded for political assets. You were released to an international facility. Years later, you're living in a sparse apartment, watching documentaries. You see footage of the schoolteacher arrested. The nurse vanished. The teenager leading a resistance cell. The documents you leaked did reach the world. Investigations continue. But Kessara is a failed state now, run by the militia. Your leak saved some lives. But the region burns. You were the instrument of truth. And truth alone did not stop the harm—your good intentions were the mechanism that enabled it all.",
		"message_label": "ENDING: YOU LEAKED THE DOCUMENTS"
	},
}

const NARRATOR_LINES = {
	"pragmatist_early": [
		"Humanitarian work is complicated. All choices help someone.",
		"You're doing more good than most people ever will.",
		"The margins of profit are what fund the margins of help.",
	],
	"pragmatist_late": [
		"You knew the consequences. You chose anyway.",
		"Good intentions pave many roads.",
		"The mechanism of your care was the mechanism of harm.",
	],
	"idealist_early": [
		"Every life you touch is a victory.",
		"Meridian Concord sees what others miss: humanity's potential.",
		"You are the bridge between hope and help.",
	],
	"idealist_late": [
		"They used your idealism like a tool.",
		"You wanted to save people. You saved the system that enslaved them.",
		"Hope is the cruelest weapon when wielded by those who profit from despair.",
	],
	"cynic_early": [
		"It's all extraction, just with better optics.",
		"You know what this is. Might as well be honest about it.",
		"Everyone's complicit. At least you're useful.",
	],
	"cynic_late": [
		"You were cynical about the wrong things.",
		"You thought you were smarter than the system. The system was smarter than you.",
		"Cynicism is just a mask for guilt.",
	],
}
