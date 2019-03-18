/***
* Name: MetaModel
* Author: mathieu
* Description: general model for the spreading of wares
* Tags: Tag1, Tag2, TagN
***/

model MetaModel

global schedules: shuffle(Consumer) + shuffle(Intermediary) + shuffle(Ware) + shuffle(Producer){
	list<string> lName;
	list<list<int>> lValue;
	list<rgb> lCol;
	
	int nb_init_Consumer <- 2 parameter: true;
	int nb_init_Intermediary_Type1 <- 1 parameter: true;
	int nb_init_Intermediary_Type2 <- 1 parameter: true;
	int nb_init_prod_Type1 <- 2 parameter: true;
	int nb_init_prod_Type2 <- 2 parameter: true;
	
	file envelopeMap_shapefile <- file("../includes/envelopeMap.shp");
	file backMap_shapefile <- file("../includes/backMap.shp");
	file caumont_shapefile <- file("../includes/caumont.shp");
//	file vernon_shapefile <- file("../includes/vernon.shp");
	geometry shape <- envelope(envelopeMap_shapefile);//rectangle(1763,2370);//square(2000);
	
	float averageDistance <- 0.0;
	float distanceMax <- 0.0;
	float distanceMin <- 0.0;
	int prodRate <- 5 parameter:true;
	int prodRateFixed <- 50 parameter:true;
	int consumRate <- 5 parameter:true;
	int consumRateFixed <- 50 parameter:true;
	float distanceCollect <- 500.0 parameter: true;
	float percentageType1 <- 0.0 parameter: true min: 0.0 max: 1.0;
	int capacityInter <- 30 parameter: true;
	float distanceCollectIntermediary <- 50.0 parameter: true;
	int stock_max_prod <- 10 parameter: true;
	int stock_max_prod_fixe <- 100 parameter: true;
	float init_price <- 100.0 parameter: true;
	
	int consumer_strategy <- 1 parameter: true min:1 max:2; //1: buy to everyone, 2: buy only to merchant (intermediary)
	//TODO : different strategies for the producer ?
	
	init {
		create BackMap from: backMap_shapefile;
		do createProd(nb_init_prod_Type1,1);
		do createProd(nb_init_prod_Type2,2);
		do createInter(nb_init_Intermediary_Type1,1);
		do createInter(nb_init_Intermediary_Type2,2);
		do createConsum(nb_init_Consumer);
	}
	
	user_command "create consum"{
		do createConsum(1);
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
	
	action createConsum(int nb_consum){
		create Consumer number: nb_consum{
			location <- any_location_in(first(BackMap));
			create Intermediary number: 1{
				location <-myself.location;
				is_Consumer <- true;
				my_consum <- myself;
				is_Producer <- false;
				my_prod <- nil;
				capacity <- myself.need;
				stock <- myself.collect;
				
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
			location <- any_location_in(first(BackMap));
			type <- typeProd;
			create Intermediary number: 1{
				location <-myself.location;
				is_Consumer <- false;
				my_consum <- nil;
				is_Producer <- true;
				my_prod <- myself;
				capacity <- myself.stockMax;
				stock <- myself.stock;
				
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
	
	action createInter(int nb_inter, int typeInter){
		create Intermediary number: nb_inter{
			location <- any_location_in(first(BackMap));
			is_Producer <- false;
			my_prod <- nil;
			is_Consumer <- false;
			my_consum <- nil;
			capacity <- rnd(capacityInter);
			price <- init_price;
			type <- typeInter;
		}
	}
	
	action destroyInter{
		ask one_of(Intermediary where ((not(each.is_Producer)) and (not(each.is_Consumer)))){
			do die ;
		}
	}
	
	//TODO : Create new consumers, new producers, desactivate consumers (when total collected>threshold, then it decreases at each step) and producers
	
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
	reflex sto when:cycle>200{
		do pause;
	}
	
}

species Consumer {
	//TODO :diversify with types and money
	//TODO : Keep the difference beetween collect and need at each step ?
	int need <- consumRateFixed + rnd(consumRate) update:consumRateFixed + rnd(consumRate) ; //in the stone case, need represents a total need (it is not updated).
	int needType1; //is a percentage of the total need, depending if the consumer is prestigious.
	int needType2;
	int collect <- 0 ;//represent the total collected from the start of the simulation
	int collectType1 <- 0 update: 0; //the update to 0 represent the consumption of all that has been collected.
	int collectType2 <- 0 update: 0; //the update to 0 represent the consumption of all that has been collected.
	bool activated <- true;
	
	Intermediary my_inter; 
	list<Ware> wareReceived <- nil;
	map presenceProd;
	map<Producer,float> quantityPerProd;
	map<Intermediary,float> probabilitiesProd; //associating each prod of type 2 with a probability to choose it to buy material
	map<Intermediary,float> percentageCollect; //associating each prod of type 1 with a percentage collected on the max possible collected per prod
	
	bool is_built; //used to stop the collect
	
	//TODO replace by initialisation action
//	init {
//		loop temp over: Producer{
//			add temp::false to:presenceProd;
//		}
//	}

	reflex updateQuantityPerProd{
		loop temp over:wareReceived{
			quantityPerProd[temp.prodPlace]<-quantityPerProd[temp.prodPlace]+temp.quantity;
		}
	}
	
	//TODO : Check the initialisation
	action initialisation{
		float distanceMinType1 <- 0.0;
		float distanceMinType2 <- 0.0;
//		if(createNewProducers){
//			if(prestigious){
//				distanceMinType2 <- distanceMaxPrestigeous;
//			} else {
//				distanceMinType2 <- distanceMaxNotPrestigeous;
//			}
//		}
		if(consumer_strategy=1){
			Intermediary tempType1 <- closest_to(Intermediary where ((each.type=1) and not each.is_Consumer),self);
			Intermediary tempType2 <- closest_to(Intermediary where ((each.type=2) and not each.is_Consumer),self);
			distanceMinType1 <- self distance_to tempType1;
			distanceMinType1 <- distanceMinType1 + tempType1.price;
//			if(!createNewProducers){
				distanceMinType2 <- self distance_to tempType2;
				distanceMinType2 <- distanceMinType2 + tempType2.price;
//			}
		}
		if(consumer_strategy=2){
			Intermediary tempType1 <- closest_to(Intermediary where ((each.type=1) and (not(each.is_Consumer) and not(each.is_Producer))),self);
			Intermediary tempType2 <- closest_to(Intermediary where ((each.type=2) and (not(each.is_Consumer) and not(each.is_Producer))),self);
			distanceMinType1 <- self distance_to tempType1;
			distanceMinType1 <- distanceMinType1 + tempType1.price;

//			if(!createNewProducers){
				distanceMinType2 <- self distance_to tempType2;
				distanceMinType2 <- distanceMinType2 + tempType2.price;
//			}		
		}
		
		loop temp over: Producer{
			add temp::false to:presenceProd;
			add temp::0.0 to: quantityPerProd;
		}
		
		//TODO : Keep the re-use at the Meta level ?
//		loop temp over: (Intermediary where(not (each.my_consum=self))/* where (not(each.is_Consumer))*/){
//			float computationType1 <- -(((self distance_to temp) + temp.price)-(distanceMinType1+distanceCollect))/distanceCollect; 
//			float computationType2 <- -(((self distance_to temp) + temp.price)-(distanceMinType2+distanceCollect))/distanceCollect;
//			if(computationType1 < 0.0){
//				computationType1 <- 0.0;
//			}
//			if(computationType1 > 1.0){
//				computationType1 <- 1.0;
//			}
//			if(computationType2 < 0.0){
//				computationType2 <- 0.0;
//			}
//			if(computationType2 > 1.0){
//				computationType2 <- 1.0;
//			}
//			if(temp.type=1){
//				add temp::computationType1 to:percentageCollect;
//			} else if (temp.type=2){
//				add temp::computationType2 to:probabilitiesProd;
//			} else if (temp.type=0){
//				add temp::computationType1 to:percentageCollect;
//				add temp::computationType2 to:probabilitiesProd;
//			}
//			
//			if(not(temp.is_Producer)){
//				if(temp.is_Consumer){
//					float computationTemp;
//					computationTemp <- -(((self distance_to temp) + temp.price)-(distanceMinType2+distanceCollect))/distanceCollect;
//					if(computationTemp < 0.0){
//						computationTemp <- 0.0;
//					}
//					if(computationTemp > 1.0){
//						computationTemp <- 1.0;
//					}
//					add self.my_inter::computationTemp to:temp.my_consum.percentageCollect;
//					add self.my_inter::computationTemp to:temp.my_consum.probabilitiesProd;
//					
//				} else {
//					float computationTemp2 <- (distanceCollectIntermediary-((self distance_to temp) + temp.price))/distanceCollectIntermediary;
//					if(computationTemp2 < 0.0){
//						computationTemp2 <- 0.0;
//					}
//					if(computationTemp2 > 1.0){
//						computationTemp2 <- 1.0;
//					}
//					add  self.my_inter::computationTemp2 to:temp.percentageCollect;
//				}
//			
//			}
//				
//		}

		needType1 <- round(need*percentageType1);
		needType2 <- need-needType1;
	}
	
	//TODO : Update needType1 et needType2
	reflex updateInterStart{
		my_inter.capacity <- need;
		my_inter.stock <- collect;
	}
	
	//TODO : Change the buying procedure to buy only the stock from producers.
	reflex buying when: activated{ //buying to all the intermediairies which are not consumer
//		do buy0;
		do buyType1(consumer_strategy); //replace depending on the method tested
		do buyType2(consumer_strategy);
	}
	
	action buyType1(int strategy){
		list<Intermediary> temp <- Intermediary where (not(each.is_Consumer) and each.type=1/* or each.type=0*/);
		temp <- temp sort_by((each distance_to self) + each.price);
		loop tempInt over: temp{
			if(percentageCollect[tempInt] > 0.0){
				if (collectType1<needType1){
					int collectTemp;
					if((tempInt.is_Producer and tempInt.my_prod.activated) and strategy=1){
					collectTemp <- min(needType1-collectType1,round(self.percentageCollect[tempInt]*(tempInt.my_prod.stockMax-tempInt.my_prod.production)));
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
					}
//					} else if (tempInt.is_Consumer and (not(tempInt.my_consum=self)) and tempInt.my_consum.is_reused and strategy=1){
//						//buy the reused of a concumer
//						collectTemp <- min(needType1-collectType1,round(self.percentageCollect[tempInt]*tempInt.my_consum.quantity_reused_type1));
//						collectType1 <- collectType1+collectTemp;
//						if(collectTemp>0){
//							write self.name + " buy re-use Type 1 " + collectTemp;
//							list<Ware> tempWares <- Ware where(each.location = tempInt.location);
//							bool endCollecting <- false;
//							int recupWare<-0;
//							loop tempLoop over: tempWares{
//								if(not endCollecting){
//									if (recupWare+tempLoop.quantity <= collectTemp) {
//										recupWare <- recupWare + tempLoop.quantity;
//										tempLoop.target <- self.location;
//										tempLoop.distance <- tempLoop.distance + tempLoop distance_to self;
//										put true at:tempLoop.prodPlace in: presenceProd;
//										add tempLoop to: wareReceived;
//									} else {
//										create Ware number: 1{
//											quantity <- collectTemp-recupWare;
//											target <- myself.location;
//											distance <- tempLoop.distance + self distance_to myself;
//											origin <- tempLoop.origin;
//											prodPlace <- tempLoop.prodPlace;
//											put true at:self.prodPlace in: myself.presenceProd;
//											add self to: myself.wareReceived;
//										}
//										tempLoop.quantity <- tempLoop.quantity - (collectTemp-recupWare);
//										recupWare <- collectTemp;
//									}
//									if(recupWare >= collectTemp){
//										endCollecting <- true;
//									}
//								}
//							}
//						}
//						ask tempInt.my_consum{
//							quantity_reused_type1 <- quantity_reused_type1 - collectTemp;
//						}	
//					}
				}
			}
		}
		my_inter.capacity <- needType1;
		my_inter.stock <- collectType1;
	
		
	}
	
	action buyType2(int strategy){
		list<Intermediary> temp <- Intermediary where (not(each.is_Consumer) and each.type=2 /*or each.type=0*/);
		temp <- temp sort_by((each distance_to self) + each.price);
		int collectTemp;
		loop tempInt over: temp{
			if(probabilitiesProd[tempInt] > 0.0){
				if (collect<needType2 and flip(self.probabilitiesProd[tempInt])){
					if(tempInt.is_Producer and tempInt.my_prod.activated and strategy=1){
					collectTemp <- min(needType2-collect,tempInt.my_prod.stockMax-tempInt.my_prod.production);
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
//					} else if(tempInt.is_Consumer){				
//						if(not(tempInt.my_consum=self) and tempInt.my_consum.is_reused and flip(self.probabilitiesProd[tempInt]) and strategy=1){
//	//					write tempInt.name;
//						collectTemp <- min(needType2-collect,tempInt.my_consum.quantity_reused_type2);
//						collect <- collect+collectTemp;
//						if(collectTemp>0){
//							write self.name + " buy re-use Type 2 " + collectTemp;
//							list<Ware> tempWares <- Ware where(each.location = tempInt.location);
//							bool endCollecting <- false;
//							int recupWare<-0;
//							loop tempLoop over: tempWares{
//								if(not endCollecting){
//									if (recupWare+tempLoop.quantity <= collectTemp) {
//										recupWare <- recupWare + tempLoop.quantity;
//										tempLoop.target <- self.location;
//										tempLoop.distance <- tempLoop.distance + tempLoop distance_to self;
//										put true at:tempLoop.prodPlace in: presenceProd;
//										add tempLoop to: wareReceived;
//									} else {
//										create Ware number: 1{
//											quantity <- collectTemp-recupWare;
//											target <- myself.location;
//											distance <- tempLoop.distance + self distance_to myself;
//											origin <- tempLoop.origin;
//											prodPlace <- tempLoop.prodPlace;
//											put true at:self.prodPlace in: myself.presenceProd;
//											add self to: myself.wareReceived;
//										}
//										tempLoop.quantity <- tempLoop.quantity - (collectTemp-recupWare);
//										recupWare <- collectTemp;
//									}
//									if(recupWare >= collectTemp){
//										endCollecting <- true;
//									}
//								}
//							}
//						}
//						ask tempInt{
//							stock <- stock - collectTemp;
//						}	
//					}
//					
//					}
					}
				}
			}
		
		}
		my_inter.capacity <- need;
		my_inter.stock <- collect;
	}
	
//	action buy0{
//		//random choice
//		loop tempInt over: shuffle(Intermediary where (not(each.is_Consumer))){
//			if (collect<need){
//				int collectTemp;
//				collectTemp <- min(need,tempInt.stock);
//				collect <- collect+collectTemp;
//				if(tempInt.is_Producer){
//					write "buy prod " + collectTemp;
//				} else {
//					write "buy inter " + collectTemp;
//				}
//				ask tempInt{
//					stock <- stock - collectTemp;
//				}
//			}
//		}
//		my_inter.capacity <- need;
//		my_inter.stock <- collect;
//	}
//	
//	action buy1 { //buy the maximum in quantity, with a price added by intermediaries
//		list<Intermediary> temp <- Intermediary where (not(each.is_Consumer));
//		temp <- temp sort_by((each distance_to self)+each.price); //distance_to is applied to the topology of the calling agent
//		loop tempInt over: temp{
//			if (collect<need){
//				int collectTemp;
//				collectTemp <- min(need,tempInt.stock);
//				collect <- collect+collectTemp;
//				if(collectTemp>0){
//					if(tempInt.is_Producer){
//						write "buy prod " + collectTemp;
//						create Ware number: 1{
//							prodPlace <- tempInt.my_prod;
//							origin <- tempInt;
//							quantity <- collectTemp;
//							target <- myself.location;
//							distance <- myself distance_to tempInt.my_prod;
//							put true at:self.prodPlace in: myself.presenceProd;
//							add self to: myself.wareReceived;
//						}
//					} else {
//						//TODO : check this part with the stoneModel
//						write "buy inter " + collectTemp;
//						list<Ware> tempWares <- Ware where(each.location = tempInt.location);
//						bool endCollecting <- false;
//						int recupWare<-0;
//						loop tempLoop over: tempWares{
//							if(not endCollecting){
//								if (recupWare+tempLoop.quantity <= collectTemp) {
//									recupWare <- recupWare + tempLoop.quantity;
//									tempLoop.target <- self.location;
//									tempLoop.distance <- tempLoop.distance + tempLoop distance_to self;
//									put true at:tempLoop.prodPlace in: presenceProd;
//									add tempLoop to: wareReceived;
//								} else {
//									create Ware number: 1{
//										quantity <- collectTemp-recupWare;
//										target <- myself.location;
//										distance <- tempLoop.distance + self distance_to myself;
//										origin <- tempLoop.origin;
//										prodPlace <- tempLoop.prodPlace;
//										put true at:self.prodPlace in: myself.presenceProd;
//										add self to: myself.wareReceived;
//									}
//									tempLoop.quantity <- tempLoop.quantity - (collectTemp-recupWare);
//									recupWare <- collectTemp;
//								}
//								if(recupWare >= collectTemp){
//									endCollecting <- true;
//								}
//							}
//						}
//					}
//					ask tempInt{
//						stock <- stock - collectTemp;
//					}
//				}
//			}
//		}
//		my_inter.capacity <- need;
//		my_inter.stock <- collect;
//	}
	
//	action buy2{ // buy to the farthest
//		list<Intermediary> temp <- Intermediary where (not(each.is_Consumer));
//		temp <- temp sort_by(1/each distance_to self); //On peut mettre des expressions dans le sort_by.
//		loop tempInt over: temp{
//			if (collect<need){
//				int collectTemp;
//				collectTemp <- min(need,tempInt.stock);
//				collect <- collect+collectTemp;
//				if(tempInt.is_Producer){
//					write "buy prod " + collectTemp;
//				} else {
//					write "buy inter " + collectTemp;
//				}
//				ask tempInt{
//					stock <- stock - collectTemp;
//				}
//			}
//		}
//		my_inter.capacity <- need;
//		my_inter.stock <- collect;
//	}
	
	aspect base {
		draw square(10) color:#blue;
	}
}

species Intermediary {
	int stock <- 0;
	int capacity <- rnd(capacityInter);
	float price <- 0.0;
	bool is_Producer;
	Producer my_prod;
	bool is_Consumer;
	Consumer my_consum;
	int type;
	map<Intermediary,float> percentageCollect;
		
	aspect base {
		if(not(is_Producer) and not(is_Consumer)){
			if (stock>0){
				draw circle(stock) color:#green;
			} else {
				draw circle(1) color:#green;
			}	
		}
	}
}

species Producer{
	int production <- prodRateFixed + rnd(prodRate) update:prodRateFixed + rnd(prodRate) ;
	int stock <- 0 ;
	int stockMax <- stock_max_prod_fixe + rnd(stock_max_prod);
	Intermediary my_inter;
	rgb color <- rgb(rnd(255),rnd(255),rnd(255));
	int type <- 1;
	bool activated <- true;
	
	reflex produit when: stock/*+production*/<stockMax{
		stock <- stock+production;
	}
	
	reflex updateInter{
		my_inter.stock<-stock;
	}
	
	reflex selling { //selling to all intermediaries not producer
		if(my_inter.stock>0){
//			do sell0;
			do sell1;
//			do sell2;
		}
	}
	
	//TODO : Add the information at the consummer level
	action sell0{
		//random choice
		loop tempInt over: shuffle(Intermediary where not(each.is_Producer)){
				if(stock>0){
					ask tempInt{
						if(stock<capacity and myself.stock>0){
						int exchange <- min(capacity-stock,myself.stock);
						stock <- stock + exchange;
						myself.stock <- myself.stock-exchange;
							if(self.is_Consumer){
								write "sell conso " + self + " " + exchange;
							} else {
								write "sell inter " + self + " " + exchange;
							}
						}
					}
				}
			}
			my_inter.stock <- stock;
	}
	
	action sell1{ //sell the maximum to the closest
		list<Intermediary> temp <- (Intermediary where not(each.is_Producer));
		temp <- temp sort_by((each distance_to self) + each.price);
		loop tempInt over: temp{
				if(stock>0){
						if(tempInt.stock<tempInt.capacity and /*myself.*/stock>0){
						int exchange <- min(tempInt.capacity-tempInt.stock,/*myself.*/stock);
						if(exchange >0){
							ask tempInt{
								stock <- stock + exchange;
							}
							/*myself.*/stock <- /*myself.*/stock-exchange;
								if(tempInt.is_Consumer){
									write "sell consu " + tempInt + " " + exchange;
									create Ware number: 1{
										prodPlace <- myself;
										origin <- myself.my_inter;
										quantity <- exchange;
										target <- tempInt.my_consum.location;
										distance <- myself distance_to tempInt.my_consum;
										put true at:self.prodPlace in: tempInt.my_consum.presenceProd;
										add self to: tempInt.my_consum.wareReceived;
									}
								} else {
									write "sell inter " + tempInt + " " + exchange;
									create Ware number: 1{
										prodPlace <- myself;
										quantity <- exchange;
										target <- tempInt.location;
										distance <- myself distance_to tempInt;
									}
								}
							}
						}
				}
			}
			my_inter.stock <- stock;
	}
	
	action sell2{ //sell to the farthest
		list<Intermediary> temp <- (Intermediary where not(each.is_Producer));
		temp <- temp sort_by(1/each distance_to self); 
		loop tempInt over: temp{
				if(stock>0){
					ask tempInt{
						if(stock<capacity and myself.stock>0){
						int exchange <- min(capacity-stock,myself.stock);
						stock <- stock + exchange;
						myself.stock <- myself.stock-exchange;
							if(self.is_Consumer){
								write "sell consum " + self + " " + exchange;
							} else {
								write "sell inter " + self + " " + exchange;
							}
						}
					}
				}
			}
			my_inter.stock <- stock;
	}
	
	aspect base {
//		if (stock>0){
//			draw triangle(stock) color:#red;
//		}else {
			draw triangle(10) color:#red;
//		}
	}
}

species Ware{ 
	int type;
	int quantity;
	Intermediary origin; //last intermediary before buy
	Producer prodPlace; //the place where the ware was produced
	point target <- nil; 
	float distance;
	
	reflex move when: target!=nil{
		location <- target;
		target <- nil;
	}
	
	aspect base {
		
	}
}

species PolygonWare { //Used to draw the polygon of wares depending on their place of production
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
}

species BackMap {//Used for the display
	aspect base{
		draw shape border: #black empty:true ;
	}
}

experiment Spreading type: gui {

	
	// Define parameters here if necessary
	// parameter "My parameter" category: "My parameters" var: one_global_attribute;
	
	// Define attributes, actions, a init section and behaviors if necessary
	// init { }
	
	//TODO : add other charts from stone model
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
		
		display distance /*refresh:every(10.0)*/  {
			chart "distance of wares" type: series {
				data "average distance" value: averageDistance color: #green;
				data "distance max" value: distanceMax color: #red;
				data "distance min" value:distanceMin color: #blue;
			}
		}
	
	//TODO : Bar charts for consumers and producers
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
				datalist legend: Producer accumulate each.name value: Producer accumulate each.production color: Producer accumulate each.color;
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