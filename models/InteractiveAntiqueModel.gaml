/***
* Name: InteractiveAntiqueModel
* Author: mathieu
* Description: ceramic model with an interface for incremental modeling
* Tags: Tag1, Tag2, TagN
***/

model InteractiveAntiqueModel

global /*schedules: [world] + Consumer + shuffle(Intermediary) + shuffle(Ware) + shuffle(Producer)*/ {
	/*
	 * Variables for the dynamic display of histograms about the presence  
	 */
	list<string> lName;
	list<list<int>> lValue;
	list<rgb> lCol;
	
	/*
	 * Total numbers of each type of species 
	 */
	int nb_total_Big_Consumer <- 2 parameter: true min:0 max:1000;
	int nb_total_Small_Consumer <- 20 parameter: true min:0 max:10000;
	int nb_total_Intermediary_type1 <- 0 parameter: true;
	int nb_total_Intermediary_type2 <- 0 parameter: true;
	int nb_total_big_prod <- 5 parameter: true;
	int nb_total_small_prod <- 10 parameter: true;
	
	/*
	 * Temporary variables for the environment
	 */
//	bool use_map <- true parameter:true;
	int areaMap <- 110 parameter: true;
	int endTime <- 300 parameter: true;
	
	file envelopeMap_shapefile <- file("../includes/envelopeMap.shp");
	file backMap_shapefile <- file("../includes/backMap.shp");
	file caumont_shapefile <- file("../includes/caumont.shp"); //TODO : REMPLACER AVEC VRAIE CARTE
	geometry shape <- square(areaMap);//<- envelope(envelopeMap_shapefile);//rectangle(1763,2370);//square(2000);
	
	/*
	 * Initial temporary values for various computations later
	 */
	float averageDistance <- 0.0;
	float distanceMax <- 0.0;
	float distanceMin <- 0.0;
	
	/*
	 * Parameters which may be used by the user
	 */
	bool createNewProducers <- true parameter: true;
	int consumRate <- 50 parameter:true min: 0 max: 100;
	int consumRateFixed <- 500 parameter:true min: 100 max: 5000;
	float distanceMaxBigCity <- 50.0 parameter:true min: 10.0 max: 1000.0;
	float distanceMaxNotBigCity <- 10.0 parameter:true min: 10.0 max: 1000.0;
	float distanceMaxIntermediary <- 1500.0 parameter:true;
	int capacityInter <- 30 parameter: true;
	int stock_max_prod <- 10 parameter: true;
	int stock_max_prod_fixe_type1 <- 100 parameter: true min: 10 max: 1000;
	int stock_max_prod_fixe_type2 <- 100 parameter: true min: 10 max: 5000;
	int initRessource <- 1000 parameter: true;
	float init_price <- 100.0 parameter: true;
	
	bool useDistance <- true;
	bool collectProbabilist <- false;
	bool consumer_stock <- false;
	
	int complexityEnvironment <- 0;//0 = no complexity; 1 = use distance; 2 = ground properties; 3 = policies; 4 = real case; 5 = open world;
	int complexityConsumer <- 0;//0 = random buy; 1 = 2 types of consumers; 2 = real localisation;
	int complexityProducer <- 0;//0 = production infinite; 1 = production not infinite; 2 = 2 types of prod; 3 = cosumers stock wares;
	/*
	 * Initialisation of the simulation
	 */
	init {
		//Initialisation of complexity, done by the user at the start of the simulation
		map valeur;
		valeur <- user_input("Complexity of the simulation",["Environment"::complexityEnvironment,"Consumer"::complexityConsumer,"Producer"::complexityProducer]);
		complexityEnvironment <- int(valeur["Environment"]);
		complexityConsumer <- int(valeur["Consumer"]);
		complexityProducer <- int(valeur["Producer"]);
		
		//initialisation of the environnement
		useDistance <- false;
		collectProbabilist <- false;
		//initialisation of the environnement
		if(complexityEnvironment>0){
			//distance variations
			useDistance <- true;
			collectProbabilist <- true;
		}
		if(complexityEnvironment>1){
			//Ground variations
			//modify the ressources of querries
		}
		if(complexityEnvironment>2){
			//integrating political areas
		}
		if(complexityEnvironment>3){
			//Real map and open map
			shape <- envelope(envelopeMap_shapefile);
			create BackMap from: backMap_shapefile;
		} else {
			shape <- square(areaMap);
			create BackMap number:1{
				shape <- square(areaMap);
				location <- {areaMap*0.5,areaMap*0.5};
			}
		}
		//if the modeler uses the map of the normandy, the quarries of Caumont, Vernon and Fecamps are automatically created
		//TODO : Mettre la carte de céramique
		if(complexityEnvironment>3){
			create Producer from: caumont_shapefile /*number: 1*/{
				type<-1;
				my_icon <- image_file("../images/Grande_carriere_v2.png");
	//			location <- any_location_in(first(BackMap));
				create Intermediary number: 1{
					location <-myself.location;
					is_Consumer <- false;
					my_consum <- nil;
					is_Producer <- true;
					my_prod <- myself;
					capacity <- myself.stockMax;
					stock <- myself.stock;
					type<-1;
					
					ask myself{
						my_inter <- myself;
					}
				}
			}
		} else {
			do createProd(nb_total_big_prod,1,complexityEnvironment);
		}
		//Creating type 2 producers (small workshop)
		do createProd(nb_total_small_prod,2,complexityEnvironment);
		//creation of initial producers, consumers
		//If complexityConsumer>2, use shapefiles to create zones where they will be a consumer at a time, not using numbers)
		
		do createConsum(nb_total_Big_Consumer,true,complexityEnvironment);
		do createConsum(nb_total_Small_Consumer,false,complexityEnvironment);
		
		do createInter(nb_total_Intermediary_type1,1);
		do createInter(nb_total_Intermediary_type1,2);
	}
	
	/*
	 * Definition of user command to add/removes entities 
	 */
	user_command "create consum"{
		do createConsum(1,true,complexityEnvironment);
	}
	
	user_command "destroy consum"{
		do destroyConsum;
	}
	
	user_command "create prod"{
		do createProd(1,1,complexityEnvironment);
	}
	
	user_command "destroy prod"{
		do destroyProd;
	}
	
	user_command "create inter"{
		do createInter(1,1);
	}
	
	user_command "destroy inter"{
		do destroyInter;
	}
	
	/*
	 * Definition of acion for the creation of entities  
	 */
	action createConsum(int nb_conso, bool sizeCity, int complexEnv){
		create Consumer number: nb_conso{
			if(complexityConsumer<3){
				location <- any_location_in(first(BackMap));
			} else {
				if(complexEnv>1){
				//Ground variations
				}
				if(complexEnv>2){
					//integrating political areas
				}
			}			
			bigCity <- sizeCity;
			create Intermediary number: 1{
				location <-myself.location;
				is_Consumer <- true;
				my_consum <- myself;
				is_Producer <- false;
				my_prod <- nil;
				capacity <- myself.need;
				stock <- myself.collect;
				type <-0;
				
				ask myself{
					my_inter <- myself;
				}
			}
			do initialisation;
		}
	}
	
	action destroyConsum{
		ask one_of(Consumer){
			do die ;
		}
	}
	
	action createProd(int nb_prod, int typeProd, int complexEnv){
		create Producer number: nb_prod{
			type<-typeProd;
			location <- any_location_in(first(BackMap));
			if(complexEnv>1){
			//Ground variations
			}
			if(complexEnv>2){
				//integrating political areas
			}
			create Intermediary number: 1{
				location <-myself.location;
				is_Consumer <- false;
				my_consum <- nil;
				is_Producer <- true;
				my_prod <- myself;
				capacity <- myself.stockMax;
				stock <- myself.stock;
				type<-typeProd;
				
				ask myself{
					my_inter <- myself;
				}
			}
		}
	}
	
	action destroyProd{
		ask one_of(Producer){
			do die ;
		}
	}
	
	action createInter(int nb_inter, int typeStone){
		create Intermediary number: nb_inter{
			location <- any_location_in(first(BackMap));
			is_Producer <- false;
			my_prod <- nil;
			is_Consumer <- false;
			my_consum <- nil;
			price <- init_price;
			type <- typeStone;
			do initialisation;
		}
	}
	
	action destroyInter{
		ask one_of(Intermediary where ((not(each.is_Producer)) and (not(each.is_Consumer)))){
			do die ;
		}
	}
	
	/*
	 * The update of the simulation done at the begining of every step.
	 * Updates the re-building of some consumers already built
	 * Updates the re-usability
	 * Creates new consumers
	 */
	 //TODO : création/disparition des petites atelirs, gestion du stockage chez les consommateurs (les grosses villes seulement)
	reflex updateSimulation{
		//TODO : Big Consumers stocking more production than their need if they collected all their need(if(collect >=need)).
		if(complexityProducer>2){
			loop tempConsum over: Consumer{
				tempConsum.has_stock <- true;
				tempConsum.quantityStocked <- 0;
				if (tempConsum.collect>=tempConsum.need){
					loop tempInt over: Producer{
					if(useDistance and tempConsum.percentageCollect[tempInt.my_inter] > 0.0){
						if (flip(tempConsum.percentageCollect[tempInt.my_inter])){
							if(tempInt.activated){
								int collectStock <- 0;
								collectStock <- round(tempConsum.percentageCollect[tempInt.my_inter]*(tempInt.stockMax-tempInt.production));
								collectStock <- round(collectStock * rnd(1000/1000));
								if(collectStock>0){
										write tempConsum.name + " buy prod Type 2 " + collectStock + " " + tempInt.name;
										tempConsum.has_stock <- true;
										tempConsum.quantityStocked <- tempConsum.quantityStocked + collectStock;
										create Ware number: 1{
											prodPlace <- tempInt;
											origin <- tempInt.my_inter;
											quantity <- collectStock;
											target <- tempConsum.location;
											distance <- tempConsum distance_to tempInt;
											put true at:self.prodPlace in: tempConsum.presenceProd;
											add self to: tempConsum.wareStocked;
										}
										//tempInt.stock <- tempInt.stock - collectTemp;
										tempInt.production <- tempInt.production + collectStock;
									}
									ask tempInt{
									stock <- stock - collectStock;
									}	
								}
							}
						}
					}
				}
			}
		}
		
		//TODO : Activate/de-activate small producers
		if(complexityProducer>1){
//			loop tempConsum over: Consumer where (each.is_reused){
//				tempConsum.collectType1 <- tempConsum.collectType1 + tempConsum.quantity_reused_type1;
//				tempConsum.quantity_reused_type1 <- 0;
//				tempConsum.collect <- tempConsum.collect + tempConsum.quantity_reused_type2;
//				tempConsum.quantity_reused_type2 <- 0;
//				tempConsum.is_reused <- false;
//			}
//			
//			list<Consumer> consumReuse <- nil;
//			if(reuse_while_built and not(reuse_while_building)){
//				consumReuse <-  Consumer where (each.is_built);
//			}
//			if(not(reuse_while_built) and reuse_while_building){
//				consumReuse <-  Consumer where (not(each.is_built));
//			}
//			if(reuse_while_built and reuse_while_building){
//				consumReuse <- list(Consumer);
//			}
//			loop tempConsum over: consumReuse {
//				if(flip(proba_reuse)){
//					tempConsum.is_reused <- true;
//					tempConsum.quantity_reused_type1 <- round(0.1*tempConsum.collectType1);
//					tempConsum.collectType1 <- tempConsum.collectType1 - tempConsum.quantity_reused_type1;
//					tempConsum.quantity_reused_type2 <- round(0.1*tempConsum.collect);
//					tempConsum.collect <- tempConsum.collect - tempConsum.quantity_reused_type2;
//				}
//			}
		}
		
		//creating new consumers ? (initialize them and add them on others intermediary buyers as potential stock)
		//Updating the collect value to 0
		loop tempConsum over: Consumer {
			tempConsum.collect <- 0;
		}
	}
	
	/* 
	 * Reflex used for the display of PolygonWare (dynamic lines between consumers and producers)
	 */
	reflex displayReflex {
		write "-------------------------";
		loop tempProd over: Producer{
			add tempProd.name to: lName;
			add Consumer collect each.quantityPerProd[tempProd] to: lValue;
			add tempProd.color to: lCol;
		}
//		ask Consumer{
////			loop tempProd over: Producer{
//				save quantityPerProd/*[tempProd]*/ to: "../results/OD"+cycle+".csv" type:"csv" rewrite: false;
////			}
//		}
		//save lValue to: "../results/OD"+cycle+".csv" type:"csv" rewrite: false;
		averageDistance <- 0.0;
		if(not empty(Ware)){
			distanceMax <- first(Ware).distance;
			distanceMin <- first(Ware).distance;
		}
		loop temp over: Ware{
			averageDistance<- averageDistance + temp.distance;
			if(temp.distance>distanceMax){
				distanceMax <- temp.distance;
			}
			if(temp.distance<distanceMin){
				distanceMin <- temp.distance;
			}
		}
		if(not empty(Ware)){
			averageDistance <- averageDistance/length(Ware);
		}
		if(not(empty(Ware))){
			loop tempConsum over: Consumer {
				loop tempProd over: tempConsum.presenceProd.keys{
					if ((tempProd !=nil) and tempConsum.presenceProd[tempProd]){
						bool exists<-false;
						loop tempPoly over: PolygonWare{
							if((tempPoly.placeProd = tempProd)and (tempPoly.consumPlace=tempConsum)){
								exists<-true;
							}
						}
						if(not exists){
							create PolygonWare number: 1{
								placeProd <- tempProd;
								consumPlace <- tempConsum;
								shape <- line([placeProd,consumPlace],150.0);
							}
						}
					}
				}
				loop tempInter over: tempConsum.previousPlace.keys{
					if ((tempInter !=nil) and tempConsum.previousPlace[tempInter]){
						bool exists<-false;
						loop tempPoly over: PolygonWarePreviousPlace{
							if((tempPoly.previousPlace = tempInter)and (tempPoly.consumPlace=tempConsum)){
								exists<-true;
							}
						}
						if(not exists){
							create PolygonWarePreviousPlace number: 1{
								previousPlace <- tempInter;
								consumPlace <- tempConsum;
								shape <- line([previousPlace,consumPlace],150.0);
							}
						}
					}
				}
			}
		}
	}
	
	/*
	 * Reflex used to stop the simulation and make a final display
	 */
	reflex stop when: cycle>endTime{
		bool isFinished <- true;
//		loop tempConso over: Consumer{
//			if not (tempConso.is_built){
//				isFinished <- false;
//			}
//		}
//		if(cycle>endTime){
//			isFinished <- true;
//		}
		if isFinished {			
			do pause;
		}
	}
	
}

/*
 * Definition of the species Consumer with its schedule (first the prestigious with priority, etc.) 
 */
species Consumer schedules: shuffle(Consumer where (each.bigCity)) + shuffle(Consumer where not(each.bigCity))
{
	bool bigCity;
	int need <- consumRateFixed + rnd(consumRate) ;
	int collect <- 0;
	Intermediary my_inter; 
	list<Ware> wareReceived <- nil;
	list<Ware> wareStocked <- nil;
	map<Producer,float> quantityPerProd;
	map<Producer,bool> presenceProd;
	map<Intermediary,bool> previousPlace; //used to display the place where wares were collected
	map<Intermediary,float> percentageCollect; //associating each prod (and stocking consummers) with a percentage collected of the max possible collected per prod
	
	bool has_stock <- false; //used to ease the computation durng the buying phase
	int quantityStocked <- 0;
	
	float distanceMaxBigWorkshop <- 0.0;
	float distanceMaxSmallWorkshop <- 0.0;
	
	image_file my_icon;
	
	/*
	 * Initialisation of Consumers: it creates a map with producers, consumers and merchants associated with their distance 
	 * so it is not necessary to compute these values at each step
	 */
	action initialisation{
		
		//If 1 type of consumer or 1 type of producer, use the bigCity distance for all the interactions)
		if(complexityConsumer<1 or complexityProducer<2){
			distanceMaxSmallWorkshop <- distanceMaxBigCity;
		} else {
			distanceMaxSmallWorkshop <- distanceMaxNotBigCity;
		}
		distanceMaxBigWorkshop <- distanceMaxBigCity;

		loop temp over: Producer{
			add temp::false to:presenceProd;
			add temp::0.0 to: quantityPerProd;
		}
		
		loop temp over: Intermediary{
			add temp::false to:previousPlace;
			//add self to other consumers
			if(temp.is_Consumer){
				add self.my_inter::false to:temp.my_consum.previousPlace;
			}
		}
		
		do computeDistance;
		
	}
	
	action computeDistance{
		loop temp over: (Intermediary where(not (each.my_consum=self))){
			if(complexityEnvironment>0){
				if self.bigCity{
					float computationType1 <- -(((self distance_to temp) + temp.price)-(distanceMaxBigWorkshop))/distanceMaxBigWorkshop;
					float computationType2 <- -(((self distance_to temp) + temp.price)-(distanceMaxSmallWorkshop))/distanceMaxSmallWorkshop;
					if(computationType1 < 0.0){
						computationType1 <- 0.0;
					}
					if(computationType1 > 1.0){
						computationType1 <- 1.0;
					}
					if(computationType2 < 0.0){
						computationType2 <- 0.0;
					}
					if(computationType2 > 1.0){
						computationType2 <- 1.0;
					}
					if(temp.type=1){
						add temp::computationType1 to:percentageCollect;
					} else if (temp.type=0){
						add temp::computationType1 to:percentageCollect;
					}
				} else {
					float computationType1 <- -(((self distance_to temp) + temp.price)-(distanceMaxSmallWorkshop))/distanceMaxSmallWorkshop;
					float computationType2 <- -(((self distance_to temp) + temp.price)-(distanceMaxSmallWorkshop))/distanceMaxSmallWorkshop;
					if(computationType1 < 0.0){
						computationType1 <- 0.0;
					}
					if(computationType1 > 1.0){
						computationType1 <- 1.0;
					}
					if(computationType2 < 0.0){
						computationType2 <- 0.0;
					}
					if(computationType2 > 1.0){
						computationType2 <- 1.0;
					}
					if(temp.type=1){
						add temp::computationType1 to:percentageCollect;
					} else if (temp.type=0){
						add temp::computationType1 to:percentageCollect;
					}
				}
				if(not(temp.is_Producer) and complexityProducer>2){
					if(temp.is_Consumer){
						float computationTemp;
						if(temp.my_consum.bigCity){
							computationTemp <- -(((self distance_to temp) + temp.price)-(distanceMaxBigWorkshop))/distanceMaxBigWorkshop;
						} else {
							computationTemp <- -(((self distance_to temp) + temp.price)-(distanceMaxSmallWorkshop))/distanceMaxSmallWorkshop;
						}
						if(computationTemp < 0.0){
							computationTemp <- 0.0;
						}
						if(computationTemp > 1.0){
							computationTemp <- 1.0;
						}
						add self.my_inter::computationTemp to:temp.my_consum.percentageCollect;
						
					} else {
						float computationTemp2 <- (distanceMaxIntermediary-((self distance_to temp) + temp.price))/distanceMaxIntermediary;
						if(computationTemp2 < 0.0){
							computationTemp2 <- 0.0;
						}
						if(computationTemp2 > 1.0){
							computationTemp2 <- 1.0;
						}
						add  self.my_inter::computationTemp2 to:temp.percentageCollect;
					}
				
				}
			} else {
				add temp::1.0 to:percentageCollect;
			}
		}
	}
	
	/*
	 * Updates the values of the intermediary entity which plays the role of commercial platform
	 */
	reflex updateInterStart {
		my_inter.capacity <- need;
		my_inter.stock <- collect;
	}
	
	/*
	 * Updates the table of relations with producers and intermediary
	 */
	/*action*/reflex updateQuantityPerProd{
		loop temp over:Intermediary{
			previousPlace[temp]<-false;
		}
		loop temp over:wareReceived{
			quantityPerProd[temp.prodPlace]<-quantityPerProd[temp.prodPlace]+temp.quantity;
			previousPlace[temp.origin]<-true;
		}
	}

	reflex buy {
		do buyCeramic(complexityConsumer,complexityProducer);
		do updateDistance;
		
	}
	
	 /*
	  *  If collect is 0 (or below a certain threshold), incerease the buying distance
	  */
	action updateDistance {
		if(collect=0){
			//agrandir le rayon en fonction de son type et recalculer les valeurs (trouver un moyen d'optimiser)
			//Augmenter la collect si on n'a ren récupéré ?
			//TODO : placer l'incrément en variable
			if(bigCity){
				distanceMaxBigWorkshop <- distanceMaxBigWorkshop + 30.0;
				distanceMaxSmallWorkshop <- distanceMaxSmallWorkshop + 15.0;
				do computeDistance;
			} else {
				distanceMaxSmallWorkshop <- distanceMaxSmallWorkshop + 10.0;
				do computeDistance;
			}
		}
	}
	
	/*
	 * Buys the maximum of wares to the closest reachable producer, and so on.
	 */
	 //TODO : DEBUG (achat aux gros ateliers à vérifier)
	action buyCeramic(int complexConsum, int complexProd){
		list<Intermediary> temp; 
		if(complexProd < 3){
			//No stock so we remove the consumers from the list of possible producers where it is possble to buy
			temp <- Intermediary where not(each.type=0);
		} else {
			temp <- Intermediary where true;
		}
		if(useDistance){
			temp <- temp sort_by((each distance_to self) + each.price);
		} else {
			temp <- shuffle(temp);
		}
		int collectTemp;
		loop tempInt over: temp{
			if(useDistance and percentageCollect[tempInt] > 0.0){
				if (collect<need and flip(self.percentageCollect[tempInt])){
					if(tempInt.is_Producer and tempInt.my_prod.activated){
					if(collectProbabilist){
						collectTemp <- min(need-collect,round(self.percentageCollect[tempInt]*(tempInt.my_prod.stockMax-tempInt.my_prod.production)));
						if (tempInt.my_prod.type=2){
							collectTemp <- round(collectTemp * rnd(1000/1000));
						}
					} else {
						collectTemp <- min(need-collect,tempInt.my_prod.stockMax-tempInt.my_prod.production);
					}
					collect <- collect+collectTemp;
					if(collectTemp>0){
							write self.name + " buy prod Type 2 " + collectTemp + " " + tempInt.name;
							create Ware number: 1{
								prodPlace <- tempInt.my_prod;
								origin <- tempInt;
								quantity <- collectTemp;
								target <- myself.location;
								distance <- myself distance_to tempInt.my_prod;
								put true at:self.prodPlace in: myself.presenceProd;
								add self to: myself.wareReceived;
							}
							//tempInt.stock <- tempInt.stock - collectTemp;
							tempInt.my_prod.production <- tempInt.my_prod.production + collectTemp;
						}
					} else if(not(tempInt.is_Producer) and not(tempInt.is_Consumer) and flip(self.percentageCollect[tempInt])){
						collectTemp <- min(need-collect,round(self.percentageCollect[tempInt]*tempInt.stock));
						collect <- collect+collectTemp;
						if(collectTemp>0){
							write self.name + " buy inter Type 2 " + collectTemp + " " + tempInt.name;
							list<Ware> tempWares <- Ware where(each.location = tempInt.location);
							bool endCollecting <- false;
							int recupWare<-0;
							loop tempLoop over: tempWares{
								if(not endCollecting){
									if (recupWare+tempLoop.quantity <= collectTemp) {
										recupWare <- recupWare + tempLoop.quantity;
										tempLoop.target <- self.location;
										tempLoop.distance <- tempLoop.distance + tempLoop distance_to self;
										put true at:tempLoop.prodPlace in: presenceProd;
										add tempLoop to: wareReceived;
									} else {
										create Ware number: 1{
											quantity <- collectTemp-recupWare;
											target <- myself.location;
											distance <- tempLoop.distance + self distance_to myself;
											origin <- tempLoop.origin;
											prodPlace <- tempLoop.prodPlace;
											put true at:self.prodPlace in: myself.presenceProd;
											add self to: myself.wareReceived;
										}
										tempLoop.quantity <- tempLoop.quantity - (collectTemp-recupWare);
										recupWare <- collectTemp;
									}
									if(recupWare >= collectTemp){
										endCollecting <- true;
									}
								}
							}
						}
						ask tempInt{
							stock <- stock - collectTemp;
						}	
					} else if(tempInt.is_Consumer){				
						if(not(tempInt.my_consum=self) and tempInt.my_consum.has_stock and flip(self.percentageCollect[tempInt])){
						collectTemp <- min(need-collect,round(self.percentageCollect[tempInt]*tempInt.my_consum.quantityStocked));
						collect <- collect+collectTemp;
						if(collectTemp>0){
							write self.name + " buy re-use Type 2 " + collectTemp;
							list<Ware> tempWares <- wareStocked;
							bool endCollecting <- false;
							int recupWare<-0;
							loop tempLoop over: tempWares{
								if(not endCollecting){
									if (recupWare+tempLoop.quantity <= collectTemp) {
										recupWare <- recupWare + tempLoop.quantity;
										tempLoop.target <- self.location;
										tempLoop.distance <- tempLoop.distance + tempLoop distance_to self;
										put true at:tempLoop.prodPlace in: presenceProd;
										add tempLoop to: wareReceived;
									} else {
										create Ware number: 1{
											quantity <- collectTemp-recupWare;
											target <- myself.location;
											distance <- tempLoop.distance + self distance_to myself;
											origin <- tempLoop.origin;
											prodPlace <- tempLoop.prodPlace;
											put true at:self.prodPlace in: myself.presenceProd;
											add self to: myself.wareReceived;
										}
										tempLoop.quantity <- tempLoop.quantity - (collectTemp-recupWare);
										recupWare <- collectTemp;
									}
									if(recupWare >= collectTemp){
										endCollecting <- true;
									}
								}
							}
						}
						ask tempInt{
							stock <- stock - collectTemp;
						}	
					}
					
					}
				}
			} else if(not useDistance){
				if (collect<need){
					if(tempInt.is_Producer and tempInt.my_prod.activated){
					collectTemp <- min(need-collect,tempInt.my_prod.stockMax-tempInt.my_prod.production);
					collect <- collect+collectTemp;
					if(collectTemp>0){
							write self.name + " buy prod Type 2 " + collectTemp + " " + tempInt.name;
							create Ware number: 1{
								prodPlace <- tempInt.my_prod;
								origin <- tempInt;
								quantity <- collectTemp;
								target <- myself.location;
								distance <- myself distance_to tempInt.my_prod;
								put true at:self.prodPlace in: myself.presenceProd;
								add self to: myself.wareReceived;
							}
							//tempInt.stock <- tempInt.stock - collectTemp;
							tempInt.my_prod.production <- tempInt.my_prod.production + collectTemp;
						}
					} else if(not(tempInt.is_Producer) and not(tempInt.is_Consumer)){
						collectTemp <- min(need-collect,tempInt.stock);
						collect <- collect+collectTemp;
						if(collectTemp>0){
							write self.name + " buy inter Type 2 " + collectTemp + " " + tempInt.name;
							list<Ware> tempWares <- Ware where(each.location = tempInt.location);
							bool endCollecting <- false;
							int recupWare<-0;
							loop tempLoop over: tempWares{
								if(not endCollecting){
									if (recupWare+tempLoop.quantity <= collectTemp) {
										recupWare <- recupWare + tempLoop.quantity;
										tempLoop.target <- self.location;
										tempLoop.distance <- tempLoop.distance + tempLoop distance_to self;
										put true at:tempLoop.prodPlace in: presenceProd;
										add tempLoop to: wareReceived;
									} else {
										create Ware number: 1{
											quantity <- collectTemp-recupWare;
											target <- myself.location;
											distance <- tempLoop.distance + self distance_to myself;
											origin <- tempLoop.origin;
											prodPlace <- tempLoop.prodPlace;
											put true at:self.prodPlace in: myself.presenceProd;
											add self to: myself.wareReceived;
										}
										tempLoop.quantity <- tempLoop.quantity - (collectTemp-recupWare);
										recupWare <- collectTemp;
									}
									if(recupWare >= collectTemp){
										endCollecting <- true;
									}
								}
							}
						}
						ask tempInt{
							stock <- stock - collectTemp;
						}	
					} else if(tempInt.is_Consumer){				
						if(not(tempInt.my_consum=self) and tempInt.my_consum.has_stock){
						collectTemp <- min(need-collect,tempInt.my_consum.quantityStocked);
						collect <- collect+collectTemp;
						if(collectTemp>0){
							write self.name + " buy re-use Type 2 " + collectTemp;
							list<Ware> tempWares <- wareStocked;
							bool endCollecting <- false;
							int recupWare<-0;
							loop tempLoop over: tempWares{
								if(not endCollecting){
									if (recupWare+tempLoop.quantity <= collectTemp) {
										recupWare <- recupWare + tempLoop.quantity;
										tempLoop.target <- self.location;
										tempLoop.distance <- tempLoop.distance + tempLoop distance_to self;
										put true at:tempLoop.prodPlace in: presenceProd;
										add tempLoop to: wareReceived;
									} else {
										create Ware number: 1{
											quantity <- collectTemp-recupWare;
											target <- myself.location;
											distance <- tempLoop.distance + self distance_to myself;
											origin <- tempLoop.origin;
											prodPlace <- tempLoop.prodPlace;
											put true at:self.prodPlace in: myself.presenceProd;
											add self to: myself.wareReceived;
										}
										tempLoop.quantity <- tempLoop.quantity - (collectTemp-recupWare);
										recupWare <- collectTemp;
									}
									if(recupWare >= collectTemp){
										endCollecting <- true;
									}
								}
							}
						}
						ask tempInt{
							stock <- stock - collectTemp;
						}	
					}
					
					}
				}
			}
		
		}
		my_inter.capacity <- need;
		my_inter.stock <- collect;
	}
	
	aspect base {
		draw square(10) color: bigCity ? #darkblue : #blue;
//		draw circle(distanceMinType2) color: #black empty: true border: #black;
	}
	aspect icon {
		//TODO : create icons for ceramic model
//		if(prestigious){
//			if(priority){
//				my_icon <- image_file("../images/Chateau.png");
//			} else {
//				my_icon <- image_file("../images/Cathedrale.png");
//			}
//		} else {
//			if (need>500){
//				my_icon <- image_file("../images/Abbaye.png");
//			} else {
//				my_icon <- image_file("../images/Eglise.png");
//			}
//		}
//		draw my_icon size:20;
	}
	
}

//This species represent the commercial parts of consumers and proucers, as well as merchants
species Intermediary  schedules: shuffle(Intermediary){
	int stock <- 0;
	int capacity <- /*rnd(*/capacityInter/*)*/;
	float price <- 0.0; 
	bool is_Producer; 
	Producer my_prod;
	bool is_Consumer;
	Consumer my_consum;
	int type; //each intermediary is specialised in a type of stone
	map<Intermediary,float> percentageCollect;
	
	action initialisation{
		float distanceMinProd <- 0.0;//self distance_to (closest_to(Producer where (each.type=self.type),self));
		loop temp over: Intermediary where ((each.is_Producer)){
			float computationPercentage <- -(((self distance_to temp) + temp.price)-(distanceMinProd+distanceMaxIntermediary))/distanceMaxIntermediary;
			if(computationPercentage < 0.0){
				computationPercentage <- 0.0;
			}
			if(computationPercentage > 1.0){
				computationPercentage <- 1.0;
			}
			add temp::computationPercentage to:percentageCollect;
			}
	}
	
	//Reflex activated only if the intermediary is a merchant
	reflex buying when: not is_Producer and not is_Consumer {
		do buy3;
	}
	
	action buy3 { //buy as a consumer
		int collect <- 0;
		list<Intermediary> temp <- Intermediary where (each.is_Producer and each.type=self.type and each.my_prod.activated);
		temp <- temp sort_by(each distance_to self);
		loop tempInt over: temp{
			if (stock<capacity and collect<capacity){
				int collectTemp;
				if(tempInt.is_Producer){
				collectTemp <- min(capacity-stock,min(capacity,round(self.percentageCollect[tempInt]*(tempInt.my_prod.stockMax-tempInt.my_prod.production))));
				collect <- collect+collectTemp;
				if(collectTemp>0){
						write "Inter buy prod " + collectTemp;
						create Ware number: 1{
							prodPlace <- tempInt.my_prod;
							origin <- tempInt;
							quantity <- collectTemp;
							target <- myself.location;
							distance <- myself distance_to tempInt.my_prod;
						}
						//tempInt.stock <- tempInt.stock - collectTemp;
						tempInt.my_prod.production <- tempInt.my_prod.production + collectTemp;
					}
				}
			}
		}
		stock <- stock + collect;
	}
	
	aspect base {
		if(not(is_Producer) and not(is_Consumer)){
			if (stock>0){
				draw circle(stock) color:type=1 ? #darkgreen : #green;
			} else {
				draw circle(1) color:type=1 ? #darkgreen : #green;
			}	
		}
	}
}


//Definition of producers
//TODO : Modifier pour garder trace de la prod précédente
species Producer  schedules: shuffle(Producer){
	int personnalInitRessource <- 0;
	int production <- 0 ;
	int productionBefore;
	int stock <- 0 ;
	int stockMax <- 0 ;//+ rnd(stock_max_prod); Indicates the maximum amount produced at each time step
	int ressource <- 0;//#max_int
	int type; //type 1 is superior to type 2;
	Intermediary my_inter;
	rgb color <- rgb(rnd(255),rnd(255),rnd(255));
	
	bool activated <- true;//used to display and schedulle only activated producer, but keeping trace of older production sites.
	
	image_file my_icon;
	
	init {
		if(complexityProducer = 0){
			ressource <- int(#max_int);
			stockMax <- ressource;
		}
		if (complexityProducer = 1){
			ressource <- int(#max_int);
			stockMax <- stock_max_prod_fixe_type1;
		}
		if(complexityProducer > 1){
			if(type=1){
				ressource <- int(#max_int);
				stockMax <- stock_max_prod_fixe_type1;
			} else {
				if(personnalInitRessource=0){
					personnalInitRessource <- initRessource;
				}
				ressource <- personnalInitRessource;
				stockMax <- stock_max_prod_fixe_type2;
			}
		}
	}
	
	reflex produce {
		productionBefore <- production;
		production <- 0;
		stock <- 0;
		if (complexityProducer > 1 and type=2) {
			if(createNewProducers){
				ressource <- ressource - productionBefore;
				if(ressource <=0){
					do desactivation;	
				}
			}
		}
	}
	
	action desactivation{
		//if has not produce anything previous year, is desactivated
		activated <- false;
		write self.name + "desactivated";
	}
	
	reflex updateInter{
		//stock represents the extra production left by producers at the previous step
		my_inter.stock<-stock;
	}
	
	aspect base {
		if(activated){
			draw triangle(10) color:type=1 ? #darkred : #red;
		}
	}
	
	aspect icon {
		//TODO : create icons for the ceramic producers
//		if(my_icon=nil){
//			my_icon <- image_file("../images/Tas_de_pierres_mieux.png");
//		}
//		draw my_icon size:20;
	}
}

//Definition of Wares. As these wares are agents in the simulation, they may be traced.
species Ware  schedules: shuffle(Ware){
	int type;
	int quantity;
	Intermediary origin;
	Producer prodPlace;
	point target <- nil;
	float distance;
	bool isInPolygon <- false;
	
	reflex move when: target!=nil{
		location <- target;
		target <- nil;
	}
	
	aspect base {
		
	}
}

species PolygonWare { //Used to draw lines of wares depending on their place of production
	Producer placeProd;
	Consumer consumPlace;
	geometry shape;
	rgb color;
	
	reflex coloring {
		if placeProd!=nil{
		color<-placeProd.color;
		}else{
			color <- #black;
		}
	}
	
	aspect base {
		draw shape color: color ;
	}
	
	aspect type1 {
		if(placeProd.type=1){
			draw shape color:color;
		}
	}
	
}

//TODO : faire un deuxième type de polygonnes ware avec l'intermédiaire précédent
species PolygonWarePreviousPlace { //Used to draw lines of wares depending on their place of production
	Intermediary previousPlace;
	Consumer consumPlace;
	geometry shape;
	rgb color;
	
	reflex coloring {
//		if previousPlace!=nil{
//		color<-placeProd.color;
//		}else{
			color <- #black;
//		}
	}
	
	aspect base {
		draw shape color: color ;
	}
	
}


species BackMap {//Used for the display
	aspect base{
		if(complexityEnvironment>3){
			draw shape border: #black empty:true ;
		} else {
			draw square(areaMap) /*at: {areaMap*0.5,areaMap*0.5}*/ border: #black empty:true ;
		}
	}
}

//grid parcels width: 1100 height: 1100 neighbors:4 {
//	rgb color <- #white;
//	bool is_occupied <- false;
//}

experiment Spreading type: gui {

	
	output {
		display main_display background: #lightgray {
			species BackMap aspect:base;
//			grid parcels lines: #black transparency: 0.5;
			species Consumer aspect: base;//aspect:base;
			species Intermediary aspect:base;
			species Producer aspect: base;//aspect:base;
//			species Ware;
			species PolygonWare;// transparency: 0.5;
		}

		display second_display background: #lightgray {
//			image "../includes/mapStone.png" transparency:0.5;
			species PolygonWare;
			species BackMap aspect:base;
		}

		display third_display background: #lightgray {
//			image "../includes/mapStone.png" transparency:0.5;
			species PolygonWare aspect:type1;
			species BackMap aspect:base;
		}
		
		display previous_place background: #lightgray {
			species PolygonWarePreviousPlace aspect: base;
			species BackMap aspect:base;
		}


		display distance /*refresh:every(10.0)*/  {
			chart "distance of wares" type: series {
				data "average distance" value: averageDistance color: #green;
				data "distance max" value: distanceMax color: #red;
				data "distance min" value:distanceMin color: #blue;
			}
		}
		
		//TODO Update to display a ratio at every step
		display "information on consumers" /*type:java2D*/{
			chart "information on consumers" type:histogram
			style:stack
			{
				datalist legend: lName value: lValue color: lCol;
			}
		} 
	
		display "production information" {
			chart "production information" type:series size: {1,1} position: {0, 0}
			{
				datalist legend: Producer accumulate each.name value: Producer accumulate each.productionBefore color: Producer accumulate each.color;
			}
		} 
	}
}
