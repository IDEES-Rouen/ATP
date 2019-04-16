/***
* Name: StoneModel
* Author: mathieu
* Description: adaptation of the meta-model to the case of stone spreading in middle-age
* Tags: Tag1, Tag2, TagN
***/

model StoneModel

global /*schedules: [world] + Consumer + shuffle(Intermediary) + shuffle(Ware) + shuffle(Producer)*/ {
	list<string> lName;
	list<list<int>> lValue;
	list<rgb> lCol;
	
	int nb_init_Consumer_prestigious <- 2 parameter: true;
	int nb_init_Consumer_not_prestigious <- 2 parameter: true;
	int nb_init_Intermediary_type1 <- 1 parameter: true;
	int nb_init_Intermediary_type2 <- 1 parameter: true;
	int nb_init_prod_type1 <- 2 parameter: true;
	int nb_init_prod_type2 <- 2 parameter: true;
	
	bool use_map <- true parameter:true;
	int areaMap <- 2000 parameter: true;
	int stopTime <- 500 parameter: true;
	bool useDistance <- true parameter: true;
	
	file envelopeMap_shapefile <- file("../includes/envelopeMap.shp");
	file backMap_shapefile <- file("../includes/backMap.shp");
	file caumont_shapefile <- file("../includes/caumont.shp");
//	file vernon_shapefile <- file("../includes/vernon.shp");
	geometry shape <- square(areaMap);//<- envelope(envelopeMap_shapefile);//rectangle(1763,2370);//square(2000);
	
	bool createNewProducers <- false parameter: true;
	
	float averageDistance <- 0.0;
	float distanceMax <- 0.0;
	float distanceMin <- 0.0;
	int nb_prioritary_prestigeous<- 1 parameter:true;
	int nb_prioritary_not_prestigeous<- 1 parameter:true;
	int consumRate <- 50 parameter:true;
	int consumRateFixed <- 500 parameter:true;
	float percentageType1Prestigeous <- 0.0 parameter: true min: 0.0 max: 1.0; //between 0 and 1
	float percentageType1NotPrestigeous <- 0.0 parameter: true min: 0.0 max: 1.0; //between 0 and 1
	float distanceMaxPrestigeous <- 500.0 parameter:true;
	float distanceMaxNotPrestigeous <- 100.0 parameter:true;
	float distanceMaxIntermediary <- 1500.0 parameter:true;
	int capacityInter <- 30 parameter: true;
	int stock_max_prod <- 10 parameter: true;
	int stock_max_prod_fixe_type1 <- 100 parameter: true;
	int stock_max_prod_fixe_type2 <- 100 parameter: true;
	float init_price <- 100.0 parameter: true;
	
	bool collectProbabilist <- false parameter: true;
	float proba_build_again <- 0.0 parameter: true min: 0.0 max: 1.0;
	float proba_reuse <- 0.0 parameter: true min: 0.0 max: 1.0;
	bool reuse_while_built <- true parameter: true;
	bool reuse_while_building <-true parameter: true;
	
	int newConsumerPrestigiousPrioritary <- 0 parameter: true; //number of new consumerprestigious and prioritary
	int newConsumerPrestigiousNotPrioritary <- 0 parameter: true; //number of new consumerprestigious and prioritary
	int newConsumerNotPrestigiousPrioritary <- 0 parameter: true; //number of new consumerprestigious and prioritary
	int newConsumerNotPrestigiousNotPrioritary <- 0 parameter: true; //number of new consumerprestigious and prioritary
	float proba_new_construction <- 0.0 parameter: true min: 0.0 max: 1.0;
	
	int consumer_strategy <- 1 parameter: true min: 1 max: 2; //1:buy to producers and intermediaries. 2:only buy to inermediairies.
	int intermediary_strategy <- 3 parameter: true min:1 max: 3; //1: buy the stock. 2: buy stock and place orders. 3: only place orders.
	int producer_strategy <- 1 parameter: true min: 1 max: 2; //1: produce just what has been oredered. 2: produce the maximum it can
	
	
	init {
		if(use_map){
			shape <- envelope(envelopeMap_shapefile);
			create BackMap from: backMap_shapefile;
		} else {
			shape <- square(areaMap);
			create BackMap number:1{
				shape <- square(areaMap);
				location <- {areaMap*0.5,areaMap*0.5};
			}
		}
		if(use_map){
			create Producer from: caumont_shapefile /*number: 1*/{
				type<-1;
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
			do createProd(nb_init_prod_type1,1);
		}
		do createProd(nb_init_prod_type2,2);
		do createInter(nb_init_Intermediary_type1,1);
		do createInter(nb_init_Intermediary_type1,2);
		do createConsum(nb_init_Consumer_prestigious,true);
		do createConsum(nb_init_Consumer_not_prestigious,false);
		ask nb_prioritary_prestigeous among Consumer where each.prestigious {
			priority <- true;
		}
		ask nb_prioritary_not_prestigeous among Consumer where not each.prestigious {
			priority <- true;
		}
	}
	
	user_command "create consum"{
		do createConsum(1,true);
	}
	
	user_command "destroy consum"{
		do destroyConsum;
	}
	
	user_command "create prod"{
		do createProd(1,1);
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
	
	action createConsum(int nb_conso, bool prestig){
		create Consumer number: nb_conso{
			location <- any_location_in(first(BackMap));
			prestigious <- prestig;
			
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
	
	action createProd(int nb_prod, int typeProd){
		create Producer number: nb_prod{
			type<-typeProd;
			location <- any_location_in(first(BackMap));
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
	
	reflex updateSimulation{
		//Re-building (loop over all consumers built, proba to augment the needs and is_built is false)
		loop tempConsum over: Consumer where (each.is_built){
			if(flip(proba_build_again) and tempConsum.need<3*consumRateFixed){
				tempConsum.is_built <- false;
				tempConsum.need <- tempConsum.need + rnd(consumRate);
				if tempConsum.prestigious {
					tempConsum.needType1 <- round(tempConsum.need*percentageType1Prestigeous);
				} else {
					tempConsum.needType1 <- round(tempConsum.need*percentageType1NotPrestigeous);
				}
				tempConsum.needType2 <- tempConsum.need-tempConsum.needType1;
			}
		}
		
		//Re-usability (clear reusability before creating new one)
		loop tempConsum over: Consumer where (each.is_reused){
			tempConsum.collectType1 <- tempConsum.collectType1 + tempConsum.quantity_reused_type1;
			tempConsum.quantity_reused_type1 <- 0;
			tempConsum.collect <- tempConsum.collect + tempConsum.quantity_reused_type2;
			tempConsum.quantity_reused_type2 <- 0;
			tempConsum.is_reused <- false;
		}
		
		list<Consumer> consumReuse <- nil;
		if(reuse_while_built and not(reuse_while_building)){
			consumReuse <-  Consumer where (each.is_built);
		}
		if(not(reuse_while_built) and reuse_while_building){
			consumReuse <-  Consumer where (not(each.is_built));
		}
		if(reuse_while_built and reuse_while_building){
			consumReuse <- list(Consumer);
		}
		loop tempConsum over: consumReuse {
			if(flip(proba_reuse)){
				tempConsum.is_reused <- true;
				tempConsum.quantity_reused_type1 <- round(0.1*tempConsum.collectType1);
				tempConsum.collectType1 <- tempConsum.collectType1 - tempConsum.quantity_reused_type1;
				tempConsum.quantity_reused_type2 <- round(0.1*tempConsum.collect);
				tempConsum.collect <- tempConsum.collect - tempConsum.quantity_reused_type2;
			}
		}
		
		//creating new consumers (initialize them and add them o others intermediary buyers as potential re-usability)
		if(flip(proba_new_construction)){
			do createConsum2(newConsumerPrestigiousPrioritary,true,true);
			do createConsum2(newConsumerPrestigiousNotPrioritary,true,false);
			do createConsum2(newConsumerNotPrestigiousPrioritary,false,true);
			do createConsum2(newConsumerNotPrestigiousNotPrioritary,false,false);
		}
	}
	
	action createConsum2(int nb_conso, bool prestig, bool prio){
		create Consumer number: nb_conso{
			location <- any_location_in(first(BackMap));
			prestigious <- prestig;
			priority <- prio;
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
	
	reflex displayReflex {
		write "-------------------------";
		loop tempProd over: Producer{
			add tempProd.name to: lName;
			add Consumer collect each.quantityPerProd[tempProd] to: lValue;
			add tempProd.color to: lCol;
		}
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
			loop tempConsum over: Consumer where not(each.is_built){
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
			}
		}
	}
	
	reflex stop /*when: cycle>500*/{
		bool isFinished <- true;
		loop tempConso over: Consumer{
			if not (tempConso.is_built){
				isFinished <- false;
			}
		}
		if(cycle>stopTime){
			isFinished <- true;
		}
		if isFinished {
			int builtTimeMax<-first(Consumer).time_to_be_built;
			int builtTimeMin<-first(Consumer).time_to_be_built;
			float builtTimeAverage<-0.0;
			loop tempConso over:Consumer{
				if tempConso.time_to_be_built > builtTimeMax {
					builtTimeMax <- tempConso.time_to_be_built;
				}
				if tempConso.time_to_be_built < builtTimeMax {
					builtTimeMin <- tempConso.time_to_be_built;
				}
				builtTimeAverage <- builtTimeAverage + tempConso.time_to_be_built;
			}
			write "Max time : " + builtTimeMax;
			write "Average time : " + builtTimeAverage/length(Consumer);
			write "Min time : " + builtTimeMin;
			
			do pause;
		}
	}
	
}

species Consumer schedules: shuffle(Consumer where (not(each.is_built) and (each.prestigious and each.priority))) + 
shuffle(Consumer where (not(each.is_built) and (each.prestigious and not(each.priority)))) + 
shuffle(Consumer where (not(each.is_built) and (not(each.prestigious) and each.priority))) + 
shuffle(Consumer where (not(each.is_built) and (not(each.prestigious) and not(each.priority))))
{
	bool prestigious;
	bool priority;
	int need <- consumRateFixed + rnd(consumRate) ;
	int needType1; //is a percentage of the total need, depending if the consumer is prestigious.
	int needType2;
	int collect <- 0 ;
	int collectType1 <-0;
	Intermediary my_inter; 
	list<Ware> wareReceived <- nil;
	map<Producer,float> quantityPerProd;
	map<Producer,bool> presenceProd;
	map<Intermediary,float> probabilitiesProd; //associating each prod of type 2 with a probability to choose it to buy material
	map<Intermediary,float> percentageCollect; //associating each prod of type 1 with a percentage collected on the max possible collected per prod
	
	bool is_built<-false;
	bool is_reused<-false;
	int quantity_reused_type1<-0; //used to indicate which quantity of stone previously collected may be used on other construction site (if not, back in collect)
	int quantity_reused_type2<-0;
	
	int time_to_be_built <- 0;
	
	float distanceMinType1 <- 0.0;
	float distanceMinType2 <- 0.0;
	
	action initialisation{
		
		if(createNewProducers){
			if(prestigious){
				distanceMinType2 <- distanceMaxPrestigeous;
			} else {
				distanceMinType2 <- distanceMaxNotPrestigeous;
			}
		}
		if(consumer_strategy=1){
			if(nb_init_prod_type1 >0){
				Intermediary tempType1 <- closest_to(Intermediary where ((each.type=1) and not each.is_Consumer),self);
				distanceMinType1 <- self distance_to tempType1;
				distanceMinType1 <- distanceMinType1 + tempType1.price;
			}
			if(nb_init_prod_type2 >0){
				Intermediary tempType2 <- closest_to(Intermediary where ((each.type=2) and not each.is_Consumer),self);
				if(!createNewProducers){
					distanceMinType2 <- self distance_to tempType2;
					distanceMinType2 <- distanceMinType2 + tempType2.price;
				}
			}
		}
		if(consumer_strategy=2){
			if(nb_init_prod_type1 >0){
				Intermediary tempType1 <- closest_to(Intermediary where ((each.type=1) and (not(each.is_Consumer) and not(each.is_Producer))),self);
				distanceMinType1 <- self distance_to tempType1;
				distanceMinType1 <- distanceMinType1 + tempType1.price;
			}
			if(nb_init_prod_type2 >0){
				Intermediary tempType2 <- closest_to(Intermediary where ((each.type=2) and (not(each.is_Consumer) and not(each.is_Producer))),self);
				if(!createNewProducers){
					distanceMinType2 <- self distance_to tempType2;
					distanceMinType2 <- distanceMinType2 + tempType2.price;
				}
			}
		}
		
		loop temp over: Producer{
			add temp::false to:presenceProd;
			add temp::0.0 to: quantityPerProd;
		}
		
		loop temp over: (Intermediary where(not (each.my_consum=self))/* where (not(each.is_Consumer))*/){
			if prestigious{
				float computationType1 <- -(((self distance_to temp) + temp.price)-(distanceMinType1+distanceMaxPrestigeous))/distanceMaxPrestigeous; 
				float computationType2 <- -(((self distance_to temp) + temp.price)-(distanceMinType2+distanceMaxPrestigeous))/distanceMaxPrestigeous;
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
				} else if (temp.type=2){
					add temp::computationType2 to:probabilitiesProd;
				} else if (temp.type=0){
					add temp::computationType1 to:percentageCollect;
					add temp::computationType2 to:probabilitiesProd;
				}
			} else {
				float computationType1 <- -(((self distance_to temp) + temp.price)-(distanceMinType1+distanceMaxNotPrestigeous))/distanceMaxNotPrestigeous;
				float computationType2 <- -(((self distance_to temp) + temp.price)-(distanceMinType2+distanceMaxNotPrestigeous))/distanceMaxNotPrestigeous;
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
				} else if (temp.type=2){
					add temp::computationType2 to:probabilitiesProd;
				} else if (temp.type=0){
					add temp::computationType1 to:percentageCollect;
					add temp::computationType2 to:probabilitiesProd;
				}
			}
			if(not(temp.is_Producer)){
				if(temp.is_Consumer){
					float computationTemp;
					if(temp.my_consum.prestigious){
						computationTemp <- -(((self distance_to temp) + temp.price)-(distanceMinType2+distanceMaxPrestigeous))/distanceMaxPrestigeous;
					} else {
						computationTemp <- -(((self distance_to temp) + temp.price)-(distanceMinType2+distanceMaxNotPrestigeous))/distanceMaxNotPrestigeous;
					}
					if(computationTemp < 0.0){
						computationTemp <- 0.0;
					}
					if(computationTemp > 1.0){
						computationTemp <- 1.0;
					}
					add self.my_inter::computationTemp to:temp.my_consum.percentageCollect;
					add self.my_inter::computationTemp to:temp.my_consum.probabilitiesProd;
					
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
				
		}
		if prestigious {
			needType1 <- round(need*percentageType1Prestigeous);
		} else {
			needType1 <- round(need*percentageType1NotPrestigeous);
		}
		needType2 <- need-needType1;
	}
	
	reflex updateInterStart when: not is_built{
		my_inter.capacity <- need;
		my_inter.stock <- collect;
	}
	
	action updateQuantityPerProd{
		loop temp over:wareReceived{
			quantityPerProd[temp.prodPlace]<-quantityPerProd[temp.prodPlace]+temp.quantity;
		}
	}
	
	reflex updateBuilt when:not is_built{
		if(collect>=needType2 and collectType1>=needType1){
			is_built <- true;
			do updateQuantityPerProd;
			write self.name + " is built";
		}
		time_to_be_built <- time_to_be_built +1;
	}
	
	reflex buyingType1 when: not is_built{
		do buyType1(consumer_strategy);
	}
	
	action buyType1(int strategy){
		list<Intermediary> temp <- Intermediary where (/*not(each.is_Consumer) and*/ each.type=1 or each.type=0);
		if(useDistance){
			temp <- temp sort_by((each distance_to self) + each.price);
		} else {
			temp <- shuffle(temp);
		}
		loop tempInt over: temp{
			if(percentageCollect[tempInt] > 0.0){
				if (collectType1<needType1){
					int collectTemp;
					if((tempInt.is_Producer and tempInt.my_prod.activated) and strategy=1){
					collectTemp <- min(needType1-collectType1,round(self.percentageCollect[tempInt]*(tempInt.my_prod.stockMax-tempInt.my_prod.production)));
					if(collectProbabilist){
						collectTemp <- round((rnd (1000) / 1000)*collectTemp);
					}
					collectType1 <- collectType1+collectTemp;
					if(collectTemp>0){
							write self.name + " buy prod Type 1 " + collectTemp + " " + tempInt.name;
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
					} else if((not(tempInt.is_Producer)) and (not(tempInt.is_Consumer))){
						collectTemp <- min(needType1-collectType1,round(self.percentageCollect[tempInt]*tempInt.stock));
						collectType1 <- collectType1+collectTemp;
						if(collectTemp>0){
							write self.name + " buy inter Type 1 " + collectTemp + " " + tempInt.name;
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
					} else if (tempInt.is_Consumer and (not(tempInt.my_consum=self)) and tempInt.my_consum.is_reused and strategy=1){
						//buy the reused of a concumer
						collectTemp <- min(needType1-collectType1,round(self.percentageCollect[tempInt]*tempInt.my_consum.quantity_reused_type1));
						collectType1 <- collectType1+collectTemp;
						if(collectTemp>0){
							write self.name + " buy re-use Type 1 " + collectTemp;
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
						ask tempInt.my_consum{
							quantity_reused_type1 <- quantity_reused_type1 - collectTemp;
						}	
					}
				}
			}
		}
		my_inter.capacity <- needType1;
		my_inter.stock <- collectType1;
	}

	reflex buyingType2 when: not is_built{
//		if(priority){
//			needType2 <- need - collectType1;
//			needType1 <- collectType1;
//		}
	//check if there is somewhere to buy. If no, activate the closer producer or create a new one. Then buy.
	if(createNewProducers){
		do activateProducer;
	}
		do buyType2(consumer_strategy);
	}
	
	action activateProducer{
		Intermediary tempProd <- (Intermediary where (each.is_Producer and (each.type=2 or each.type=0))) closest_to self;
		if((tempProd distance_to self)>self.distanceMinType2){
				do createProducerType2(self,self.distanceMinType2);
			} else {
				//activate the producer if not activated
				tempProd.my_prod.activated <- true;
		}
		
	}
	
	action createProducerType2(Consumer test,float distance){
		create Producer number: 1{
			type<-2;
			geometry area <- (circle(distance,test.location)) inter first(BackMap);
			location <- any_location_in(area);
			create Intermediary number: 1{
				location <-myself.location;
				is_Consumer <- false;
				my_consum <- nil;
				is_Producer <- true;
				my_prod <- myself;
				capacity <- myself.stockMax;
				stock <- myself.stock;
				type<-2;
				
				ask myself{
					my_inter <- myself;
				}
			}
			loop temp over: (Intermediary where (not(each.is_Producer))){
				if(temp.is_Consumer){
					float computationTemp;
					if(temp.my_consum.prestigious){
						computationTemp <- -(((self distance_to temp) + temp.price)-(test.distanceMinType2+distanceMaxPrestigeous))/distanceMaxPrestigeous;
					} else {
						computationTemp <- -(((self distance_to temp) + temp.price)-(test.distanceMinType2+distanceMaxNotPrestigeous))/distanceMaxNotPrestigeous;
					}
					if(computationTemp < 0.0){
						computationTemp <- 0.0;
					}
					if(computationTemp > 1.0){
						computationTemp <- 1.0;
					}
					add self.my_inter::computationTemp to:temp.my_consum.percentageCollect;
					add self.my_inter::computationTemp to:temp.my_consum.probabilitiesProd;
					
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
		}
	}
	
	action buyType2(int strategy){
		list<Intermediary> temp <- Intermediary where (/*not(each.is_Consumer) and */each.type=2 or each.type=0);
		if(useDistance){
			temp <- temp sort_by((each distance_to self) + each.price);
		} else {
			temp <- shuffle(temp);
		}
		int collectTemp;
		loop tempInt over: temp{
			if(probabilitiesProd[tempInt] > 0.0){
				if (collect<needType2 and flip(self.probabilitiesProd[tempInt])){
					if(tempInt.is_Producer and tempInt.my_prod.activated and strategy=1){
					collectTemp <- min(needType2-collect,tempInt.my_prod.stockMax-tempInt.my_prod.production);
					if(collectProbabilist){
						collectTemp <- round((rnd (1000) / 1000)*collectTemp);
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
					} else if(not(tempInt.is_Producer) and not(tempInt.is_Consumer) and flip(self.probabilitiesProd[tempInt])){
						collectTemp <- min(needType2-collect,tempInt.stock);
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
						if(not(tempInt.my_consum=self) and tempInt.my_consum.is_reused and flip(self.probabilitiesProd[tempInt]) and strategy=1){
	//					write tempInt.name;
						collectTemp <- min(needType2-collect,tempInt.my_consum.quantity_reused_type2);
						collect <- collect+collectTemp;
						if(collectTemp>0){
							write self.name + " buy re-use Type 2 " + collectTemp;
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
					}
					
					}
				}
			}
		
		}
		my_inter.capacity <- need;
		my_inter.stock <- collect;
	}
	
	aspect base {
		draw square(10) color: prestigious ? #darkblue : #blue;
	}
}

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
		float distanceMinProd <- self distance_to (closest_to(Producer where (each.type=self.type),self));
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
	
	reflex buying when: not is_Producer and not is_Consumer {
		if intermediary_strategy=1 {
			do buy1;
		}
		if intermediary_strategy=2{
			do buy2;
		}
		if intermediary_strategy=3{
			do buy3;
		}
	}
	
	action buy1 { //buy only extra production
		int collect <- 0;
		list<Intermediary> temp <- Intermediary where (each.is_Producer and each.type=self.type and each.my_prod.activated);
		temp <- temp sort_by(each distance_to self);
		loop tempInt over: temp{
			if (stock<capacity and collect<capacity){
				int collectTemp;
				if(tempInt.is_Producer){
				collectTemp <- min(capacity-stock,min(capacity,round(self.percentageCollect[tempInt]*(tempInt.stock))));
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
						tempInt.stock <- tempInt.stock - collectTemp;
						//tempInt.my_prod.production <- tempInt.my_prod.production + collectTemp;
						stock <- stock + collect;
					}
				}
			}
		}
	}
	
	action buy2 { //buy as a consumer + extra production
		int collect <- 0;
		list<Intermediary> temp <- Intermediary where (each.is_Producer and each.type=self.type and each.my_prod.activated);
		temp <- temp sort_by(each distance_to self);
		loop tempInt over: temp{
			if (stock<capacity and collect<capacity){
				int collectTemp;
				if(tempInt.is_Producer){
					collectTemp <- min(capacity-stock,min(capacity,round(self.percentageCollect[tempInt]*(tempInt.stock)))); //buying extra production in priority
					collect <- collect+collectTemp;
					stock <- collect;
					
					if(collectTemp>0){
							write "Inter buy prod " + collectTemp;
							create Ware number: 1{
								prodPlace <- tempInt.my_prod;
								origin <- tempInt;
								quantity <- collectTemp;
								target <- myself.location;
								distance <- myself distance_to tempInt.my_prod;
							}
							tempInt.stock <- tempInt.stock - collectTemp;
							//tempInt.my_prod.production <- tempInt.my_prod.production + collectTemp;
						}
					if (stock<capacity){
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
				stock <- stock + collect;
			}
		}
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

species Producer  schedules: shuffle(Producer){
	int production <- 0 ;
	int productionBefore;
	int stock <- 0 ;
	int stockMax <- 0 ;//+ rnd(stock_max_prod);
	int type; //type 1 is superior to type 2;
	Intermediary my_inter;
	rgb color <- rgb(rnd(255),rnd(255),rnd(255));
	
	bool activated <- true;//used to display and schedulle only activated producer, but keeping trace of older production sites.
	
	init {
		if(type=1){
			stockMax <- stock_max_prod_fixe_type1;
		} else {
			stockMax <- stock_max_prod_fixe_type2;
		}
	}
	
	reflex produce {
		if producer_strategy=1{
			productionBefore <- production;
			production <- 0;
			stock <- 0;
			if (productionBefore <=0 and type=2) {
				if(createNewProducers){
					do desactivation;
				}
			}
		}
		if producer_strategy=2{
			productionBefore <- production;
			production <- 0;
			stock <- stockMax-productionBefore;
		}
	}
	
	action desactivation{
		//if has not produce anything previous year, is desactivated
		activated <- false;
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
}

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

species BackMap {//Used for the display
	aspect base{
		if(use_map){
			draw shape border: #black empty:true ;
		} else {
			draw square(areaMap) /*at: {areaMap*0.5,areaMap*0.5}*/ border: #black empty:true ;
		}
	}
}

experiment Spreading type: gui {

	
	// Define parameters here if necessary
	// parameter "My parameter" category: "My parameters" var: one_global_attribute;
	
	// Define attributes, actions, a init section and behaviors if necessary
	// init { }
	
	
	output {
	// Define inspectors, browsers and displays here
	
	// inspect one_or_several_agents;
	//
		display main_display background: #lightgray { 
			species BackMap aspect:base;
			species Consumer aspect:base;
			species Intermediary aspect:base;
			species Producer aspect:base;
			species Ware;
			species PolygonWare transparency: 0.5;
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

		display distance /*refresh:every(10.0)*/  {
			chart "distance of wares" type: series {
				data "average distance" value: averageDistance color: #green;
				data "distance max" value: distanceMax color: #red;
				data "distance min" value:distanceMin color: #blue;
			}
		}
		
		display "information on consumers" /*type:java2D*/{
			chart "information on consumers" type:histogram
			style:stack
			{
				datalist legend: lName value: lValue color: lCol;
//				loop tempProd over:Producer{
//					data tempProd.name style: stack
//					value:(Consumer collect each.quantityPerProd[tempProd])
//					color: tempProd.color;
//				}
			}
		} 
	
		display "production information" {
			chart "production information" type:series size: {0.5,1} position: {0, 0}
			{
				datalist legend: Producer accumulate each.name value: Producer accumulate each.productionBefore color: Producer accumulate each.color;
//				loop tempProd over: Producer {
//					data tempProd.name value: tempProd.productionBefore color:tempProd.color;
//				}
			}
			chart "stock information" type:series size: {0.5,1} position: {0.5, 0}
			{
				datalist legend: Producer accumulate each.name value: Producer accumulate each.stock color: Producer accumulate each.color;
//				loop tempProd over: Producer {
//					data tempProd.name value: tempProd.stock color:tempProd.color;
//				}
			}
		} 
	
	}
}

