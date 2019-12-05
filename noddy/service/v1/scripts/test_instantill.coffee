
import fs from 'fs'

API.add 'service/oab/scripts/test_instantill',
  get: 
    roleRequired: 'root'
    action: () ->
      results = {journal: {had: 0, found: 0}, found: 0, journals: 0, data: []}
      outfile = '/home/cloo/static/test_isntantill_results.csv'
      fs.writeFileSync outfile, 'from,search,match,title,doi,journal,issn,open,subscription,url,journal\n'
      
      counter = 0
      for t in titles
        qry = {title: t, plugin: 'instantill', refresh: true, from: this.queryParams.from ? this.user._id}
        if this.queryParams.journals
          try qry.journal = journals[counter]
        res = API.service.oab.find qry
        results.data.push res
        console.log res
        fs.appendFileSync outfile, '"' + (this.queryParams.from ? this.user._id) + '"'
        fs.appendFileSync outfile, ',"' + t + '","' + res.match + '"'
        fs.appendFileSync outfile, ',"' + (res.meta?.article?.title ? '') + '","' + (res.meta?.article?.doi ? '') + '","' + (res.meta?.article?.journal ? '') + '","' + (res.meta?.article?.issn ? '') + '"'
        fs.appendFileSync outfile, ',"' + (if res.availability? and res.availability.length and res.availability[0].url? then res.availability[0].url else '') + '"'
        fs.appendFileSync outfile, ',"' + (res.ill?.subscription?.found ? '') + '","' + (res.ill?.subscription?.url ? '') + '"'
        fs.appendFileSync outfile, ',"' + (res.ill?.subscription?.journal ? '') + '"'
        fs.appendFileSync outfile, '\n'
        if qry.journal
          results.journal.had += 1
        else if res.meta?.article?.journal
          results.journal.found += 1
        results.found += 1 if res.ill?.subscription?.found
        results.journals += 1 if res.ill?.subscription?.journal
        counter += 1
        
      API.mail.send
        to: 'alert@cottagelabs.com'
        subject: 'InstantILL test complete'
        text: 'https://static.cottagelabs.com/test_isntantill_results.csv\n\nfound ' + results.found + ' of which ' + results.journals + ' are journals without link\n\n' + results.journal.had + ' had journal and ' + results.journal.found + ' found journal\n\n' + JSON.stringify results.data
      return results




titles = [
  'Chronotopic maps in human supplementary motor area',
  'Preparing Children with Post-Traumatic Stress Disorder for Court: A Multidisciplinary Approach.',
  'The Role of Judges in Implementing Fostering Connections: Health and Educational Well-being Provisions.',
  'Teaching empathy to medical students: an updated, systematic review.',
  'Collective Memory Meets Organizational Identity: Remembering to Forget in a Firms Rhetorical History',
  'Creative, Rare, Entitled, and Dishonest: How Commonality of Creativity in One’s Group Decreases an Individuals Entitlement and Dishonesty',
  'Resilience in Organizations: An Integrative Multilevel Review and Agenda for the Future',
  'Corporate Work-Family Policies and Gender-Religiosity Intersectionality.',
  'The effects of the interactive use of management control systems on product innovation',
  'Management control systems and strategy: A critical review',
  'Preferences for shared decision making in chronic pain patients compared with patients during a premedication visit.',
  'Connection between inflammatory markers, antidepressants and depression',
  'The effect of rational emotive behavior therapy (REBT) on antiretroviral therapeutic adherence and mental health in women infected with HIV/AIDS.',
  'Ependymal cells: biology and pathology.',
  'Are electromyographic patterns during gait related to abnormality level of the gait in patients with spastic cerebral palsy?',
  'Between the sheets - or how to keep babies warm',
  'Updating SIDS risk reduction advice has the potential to further reduce infant deaths in Sweden.',
  'Quality improvement effort to reduce hypothermia among high-risk infants on a mother-infant unit',
  'Autonomy of elder patients suffering from cancer: the right to know about their diagnosis.',
  'Critical evaluation of appreciative inquiry: Bridging an apparent paradox',
  'Development and assessment of film excerpts used for emotion elicitation',
  'Adaptation to Global Change in Farmer-Managed Irrigation Systems of the Gandaki Basin in Nepal',
  'Carbon Nanotube/Hexa‐peri‐hexabenzocoronene Bilayers for Discrimination Between Nonpolar Volatile Organic Compounds of Cancer and Humid Atmospheres',
  'Stress and the urge to drink',
  'The Relationship Between Provider Competence, Content Exposure, and Consumer Outcomes in Illness Management and Recovery Programs',
  'Business as Usual? On Managerialization and the Adoption of the Balanced Scorecard in a Democratically Governed Civil Society Organization',
  'The road to market.',
  'From the streets, to the emergency department, and back: a model of emergency care for the homeless',
  'Lithium Silicide Surface Enrichment: A Solution to Lithium Metal Battery',
  'The Role of Palynology in Archaeology',
  'The water vapor transport model at the regional boundary during the Meiyu period',
  'Comparing Two Emotion Models for Deriving Affective States from Physiological Data',
  'Coercion, fetishes and suffering in the daily lives of young Nigerian women in Italy',
  'After-School Crime or After-School Programs: Tuning in to the Prime Time for Violent Juvenile Crime and Implications for National Policy. A Report to the United States Attorney General.',
  'Concurrent validity of two instruments (the Confusion Assessment Method and the Delirium Rating Scale) in the detection of delirium among older medical inpatients.',
  'Living arrangements and loneliness of South Asian immigrant seniors in Edmonton, Canada.',
  'Adolescent cyberbullying: A review of characteristics, prevention and intervention strategies',
  'DSM-IV paraphilia: Descriptions, demographics and treatment interventions',
  'Laboratory stress response in humans: Genetic determinants and longitudinal findings',
  'Experimental and cross-sectional examinations of the relations among implicit alcohol cognitions, stress, and drinking',
  'Laboratory stress response in humans: genetic determinants and longitudinal findings',
  'Choosing to abstain: Differences in implicit & explicit motivation to consume alcohol between lifelong and short-term abstainers',
  'Access and Scholarly Use of Web Archives',
  'Alteration of tektite to form weathering products',
  'Modulation of neuroimmune parameters during the eustress of humor-associated mirthful laughter',
  'The Contested Legacies of Indigenous Debt Bondage in Southeast Asia: Indebtedness in the Vietnamese Sex Sector',
  'Color-Blindness and Commonality',
  'Improving Young English Learners’ Language and Literacy Skills Through Teacher Professional Development: A Randomized Controlled Trial',
  'Abby as Ally: An Argument for Culturally Disruptive Pedagogy',
  'Common Skin Rashes in Children',
  'A Picture of American Generosity: Participation in Giving Behaviors',
  'Distinctions between social support concepts, measures, and models',
  'Measurement of human service staff satisfaction: Development of the Job Satisfaction Survey',
  'The Role of Neighborhood Context and School Climate in School-Level Academic Achievement',
  'Arsenic ingestion and internal cancers: A review.',
  'Evidence-based interventions are necessary but not sufficient for achieving outcomes in each setting in a complex world',
  'Autism in African American families: clinical-phenotypic findings.',
  'The Management of Myelomeningocele Study: full cohort 30-month pediatric outcomes',
  'Prenatally diagnosed fetal conditions in the age of fetal care: does who counsels matter?',
  'Managing the sexually transmitted disease pandemic: A time for reevaluation',
  'Maternal-fetal surgery for myelomeningocele: Neurodevelopmental outcomes at 2 years of age.',
  'Adolescents as mothers: results of a progam for low-income pregnant teenagers with some emphasis upon infants development.',
  'Aerobic Exercise Training in Very Severe Chronic Obstructive Pulmonary Disease: A Systematic Review and Meta-Analysis.',
  'Standards of Evidence for Behavioral Counseling Recommendations.',
  'Understanding Research Gaps and Priorities for Improving Behavioral Counseling Interventions: Lessons Learned From the U.S. Preventive Services Task Force.',
  'Culturally Competent Healthcare Systems: A Systematic Review',
  'Failure to Identify a Human Trafficking Victim.',
  'The relationship of socioeconomic status to health.',
  'Abstinence, Sex, and Virginity: Do They Mean What We Think They Mean?',
  'Asymmetric synthesis of a-amino acids via homologation of Ni(II) complexes of glycine Schiff bases; Part 1: alkyl halide alkylations.',
  'Some of the amino acid chemistry going on in the Laboratory of Amino Acids, Peptides and Proteins.',
  'The mood congruence memory effect: Differential recognition of sadness and joy words',
  'Extracting natural dyes from wool—an evaluation of extraction methods',
  'Determination of Barbiturates by Solid-Phase Microextraction and Capillary Electrophoresis',
  'The intermingled history of occupational therapy and anatomical education: A retrospective exploration.',
  'Influence of Anchor Lipids on the Homogeneity and Mobility of Lipid Bilayers on Thin Polymer Films',
  'Perceptions of the Effect of Information and Communication Technology on the Quality of Care Delivered in Emergency Departments: A Cross-Site Qualitative Study',
  'Advances in spatial epidemiology and geographic information systems',
  'Short Sleep Duration Across Income, Education, and Race/Ethnic Groups: Population Prevalence and Growing Disparities During 34 Years of Follow-Up',
  'Geoethics and Professionalism: The Responsible Conduct of Scientists',
  'Epilepsy in India I: Epidemiology and public health',
  'Performance Characteristics of Fecal Immunochemical Tests for Colorectal Cancer and Advanced Adenomatous Polyps: A Systematic Review and Meta-analysis',
  'Estimating Prognosis with the Aid of a Conversational-Mode Computer Program',
  'Validation of a low-cost EEG device for mood induction studies',
  'Evaluating virtual reality mood induction procedures with portable EEG devices',
  'Insect Seasonality: Diapause Maintenance, Termination, and Postdiapause Development',
  'Insect Cuticle Sclerotization',
  'Visualizing knowledge domains',
  'The Emergence of a Circuit Model for Addiction.',
  'Beyond work-life integration',
  'Political Repression: Iron Fists, Velvet Gloves, and Diffuse Control',
  'Linking global citizenship, undergraduate nursing education, and professional nursing: curricular innovation in the 21st century',
  'Drilling on Crary Ice Rise, Antarctica',
  'Grappling with the Oral Skills: The learning processes of the low-educated adult second language and literacy learner',
  'No lake wobegon in beijing? The impact of culture on the perception of relative ranking.',
  'The multi/plural turn, postcolonial theory, and neoliberal multiculturalism: Complicities and implications for applied linguistics.',
  'Smartphone-based colorimetric analysis for detection of saliva alcohol concentration',
  'The Prediction of Outcome in Schizophrenia I. Characteristics of Outcome',
  'A Comparison of Clinical and Diagnostic Interview Schedule Diagnoses Physician Reexamination of Lay-Interviewed Cases in the General Population',
  'Effects of a program to prevent social isolation on loneliness, depression, and subjective well-being of older adults: A randomized trial among older migrants in Japan'
]


journals = [
  '',
  'ABA child law practice.',
  'ABA child law practice.',
  'Academic medicine',
  'Academy of Management Journal',
  'Academy of Management journal',
  'Academy of Management proceedings.',
  'Academy of Management proceedings.',
  'Accounting, organizations and society',
  'Accounting, organizations and society',
  'Acta Anaesthesiologica Scandinavica',
  'Acta clinica Croatica (Tisak)',
  'Acta medica Indonesiana.',
  'Acta neuropathologica.',
  'Acta of bioengineering and biomechanics',
  'Acta pædiatrica (Oslo)',
  'Acta pædiatrica (Oslo)',
  'Acta pædiatrica.',
  'Acta paulista de enfermagem',
  'Action research.',
  'Activitas Nervosa Superior Rediviva',
  'Adaptation to Global Change in Farmer-Managed Irrigation Systems of the Gandaki Basin in Nepal',
  'Adavnce Materials',
  'Addictive behaviors',
  'Administration and policy in mental health and mental health services research',
  'Administrative theory & praxis : a journal of dialogue in public administration theory.',
  'Administrative theory & praxis : a journal of dialogue in public administration theory.',
  'Advanced emergency nursing journal',
  'Advanced Materials',
  'Advances in archaeological method and theory.',
  'Advances in atmospheric sciences',
  'Affect and emotion in human-computer interaction : from theory to applications',
  'Africa',
  'After-School Crime or After-School Programs: Tuning in to the Prime Time for Violent Juvenile Crime and Implications for National Policy. A Report to the United States Attorney General.',
  'Age and ageing',
  'Ageing and society',
  'Aggression and violent behavior.',
  'Aggression and violent behavior.',
  'Alcohol.',
  'Alcohol.',
  'Alcohol.',
  'Alcoholism: clinical and experimental research.',
  'Alexandria.',
  'Alteration of tektite to form weathering products',
  'Alternative therapies in health and medicine.',
  'American Anthropologist',
  'American Behavioral Scientist',
  'American educational research journal',
  'American Educational Research Journal',
  'American family physician.',
  'American Generosity: Who Gives & Why',
  'American Journal of Community Psychology',
  'American Journal of Community Psychology',
  'American journal of community psychology',
  'American journal of epidemiology.',
  'American Journal of Evaluation',
  'American journal of medical genetics. Part B, Neuropsychiatric genetics',
  'American journal of obstetrics and gynecology',
  'American journal of obstetrics and gynecology',
  'American journal of obstetrics and gynecology.',
  'American journal of obstetrics and gynecology.',
  'American Journal of Orthopsychiatry',
  'American journal of physical medicine & rehabilitation',
  'American journal of preventive medicine',
  'American journal of preventive medicine',
  'American journal of preventive medicine.',
  'American Journal of Psychiatry',
  'American journal of public health (1971)',
  'American journal of sexuality education',
  'Amino acids',
  'Amino acids.',
  'Anales de psicología : revista de la Facultad de Filosofía y Ciencias de la Educación, Sección de Psicología, Universidad de Murcia',
  'Analytical and Bioanalytical Chemistry',
  'Analytical Chemistry',
  'Anatomical sciences education',
  'Angewandte Chemie International Edition in English',
  'Annals of Emergency Medicine: An International Journal',
  'Annals of Epidemiology',
  'Annals of epidemiology',
  'Annals of Geophysics',
  'Annals of Indian Academy of Neurology AIAN.',
  'Annals of Internal Medicine',
  'Annals of internal medicine.',
  'Annual review of cybertherapy and telemedicine',
  'Annual review of cybertherapy and telemedicine',
  'Annual review of entomology.',
  'Annual review of entomology.',
  'ANNUAL REVIEW OF INFORMATION SCIENCE AND TECHNOLOGY',
  'Annual review of neuroscience.',
  'Annual review of psychology',
  'Annual review of sociology.',
  'ANS. Advances in Nursing Science',
  'Antarctic Journal of the United States',
  'Apples (Jyväskylä, Finland)',
  'Applied cognitive psychology',
  'Applied Linguistics',
  'Applied Optics',
  'Arch Gen Psychiatry',
  'Archives of general psychiatry',
  'Archives of gerontology and geriatrics.'
]



