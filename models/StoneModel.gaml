/***
* Name: StoneModel
* Author: mathieu
* Description: adaptation of the meta-model to the case of stone sprading in middle-age
* Tags: Tag1, Tag2, TagN
***/

model StoneModel

global /*schedules: [world] + shuffle(Consumer) + shuffle(Intermediary) + shuffle(Ware) + shuffle(Producer)*/ {
	int nb_init_Consumer_prestigious <- 2 parameter: true;
	int nb_init_Consumer_not_prestigious <- 2 parameter: true;
	int nb_init_Intermediary_type1 <- 1 parameter: true;
	int nb_init_Intermediary_type2 <- 1 parameter: true;
	int nb_init_prod_type1 <- 2 parameter: true;
	int nb_init_prod_type2 <- 2 parameter: true;
	
	file envelopeMap_shapefile <- file("../includes/envelopeMap.shp");
	file backMap_shapefile <- file("../includes/backMap.shp");
	file caumont_shapefile <- file("../includes/caumont.shp");
	file vernon_shapefile <- file("../includes/vernon.shp");
	geometry shape <- envelope(envelopeMap_shapefile);//rectangle(1763,2370);//square(2000);
	
	float averageDistance <- 0.0;
	float distanceMax <- 0.0;
	float distanceMin <- 0.0;
	int nb_prioritary_prestigeous<- 1 parameter:true;
	int nb_prioritary_not_prestigeous<- 1 parameter:true;
	int prodRate <- 5 parameter:true;
	int prodRateFixed <- 50 parameter:true;
	int consumRate <- 50 parameter:true;
	int consumRateFixed <- 500 parameter:true;
	float percentageType1Prestigeous <- 0.0 parameter: true; //between 0 and 1
	float percentageType1NotPrestigeous <- 0.0 parameter: true; //between 0 and 1
	float distanceMaxPrestigeous <- 1000.0 parameter:true;
	float distanceMaxNotPrestigeous <- 100.0 parameter:true;
	int capacityInter <- 30 parameter: true;
	int stock_max_prod <- 10 parameter: true;
	int stock_max_prod_fixe <- 100 parameter: true;
	float init_price <- 100.0 parameter: true;
	
	int consumer_strategy <- 1 parameter: true min: 1 max: 2; //1:buy to producers and intermediaries. 2:only buy to inermediairies.
	int intermediary_strategy <- 1 parameter: true min:1 max: 3; //1: buy the stock. 2: buy stock and place orders. 3: only place orders.
	int producer_strategy <- 1 parameter: true min: 1 max: 2; //1: produce just what has been oredered. 2: produce the maximum it can
	
	init {
		create BackMap from: backMap_shapefile;
		if(nb_init_prod_type1=2){
		create Producer from: caumont_shapefile number: 1{
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
		create Producer from: vernon_shapefile number: 1{
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
			do initialisation;
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
			capacity <- rnd(capacityInter);
			price <- init_price;
			type <- typeStone;
		}
	}
	
	action destroyInter{
		ask one_of(Intermediary where ((not(each.is_Producer)) and (not(each.is_Consumer)))){
			do die ;
		}
	}
	
	reflex displayReflex {
		write "-------------------------";
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
	
	reflex stop{
		bool isFinished <- true;
		loop tempConso over: Consumer{
			if not (tempConso.is_built){
				isFinished <- false;
			}
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
	int time_to_be_built <- 0;
	
	action initialisation{
		float distanceMinType1 <- self distance_to (closest_to(Producer where (each.type=1),self));
		float distanceMinType2 <- self distance_to (closest_to(Producer where (each.type=2),self));
		loop temp over: Producer{
			add temp::false to:presenceProd;
			add temp::0.0 to: quantityPerProd;
			write self distance_to temp;
		}
		loop temp over: Intermediary where (not(each.is_Consumer)){
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
				} else {
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
				} else {
					add temp::computationType2 to:probabilitiesProd;
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
		if(consumer_strategy=1){
			do buy1Type1;
		}
		if(consumer_strategy=2){
			do buy2Type1;
		}
	}
	
	//TODO : clean by using less copy/paste
	action buy1Type1 {
		list<Intermediary> temp <- Intermediary where (not(each.is_Consumer) and each.type=1);
		temp <- temp sort_by((each distance_to self) + each.price);
		loop tempInt over: temp{
			if (collectType1<needType1){
				int collectTemp;
				if(tempInt.is_Producer){
				collectTemp <- min(needType1-collectType1,round(self.percentageCollect[tempInt]*(tempInt.my_prod.stockMax-tempInt.my_prod.production)));
				collectType1 <- collectType1+collectTemp;
				if(collectTemp>0){
						write self.name + " buy prod Type 1 " + collectTemp;
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
				} else {
					collectTemp <- min(needType1-collectType1,round(self.percentageCollect[tempInt]*tempInt.stock));
					collectType1 <- collectType1+collectTemp;
					if(collectTemp>0){
						write self.name + " buy inter Type 1 " + collectTemp;
						list<Ware> tempWares <- Ware where(each.location = tempInt.location);
						bool endCollecting <- false;
						int recupWare<-0;
						loop tempLoop over: tempWares{
							if(not endCollecting){
								if (recupWare+tempLoop.quantity <= collectTemp) {
									recupWare <- recupWare + tempLoop.quantity;
									tempLoop.target <- self.location;
									tempLoop.distance <- tempLoop.distance + tempLoop distance_to self;
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
		my_inter.capacity <- needType1;
		my_inter.stock <- collectType1;
	}
	
	action buy2Type1 {
		list<Intermediary> temp <- Intermediary where (not(each.is_Consumer) and each.type=1);
		temp <- temp sort_by((each distance_to self) + each.price);
		loop tempInt over: temp{
			if (collectType1<needType1){
				int collectTemp;
				if (not(tempInt.is_Producer)and not(tempInt.is_Consumer)){
				collectTemp <- min(needType1-collectType1,tempInt.stock);
				collectType1 <- collectType1+collectTemp;
				if(collectTemp>0){
						write self.name + " buy inter Type 1 " + collectTemp;
						list<Ware> tempWares <- Ware where(each.location = tempInt.location);
						bool endCollecting <- false;
						int recupWare<-0;
						loop tempLoop over: tempWares{
							if(not endCollecting){
								if (recupWare+tempLoop.quantity <= collectTemp) {
									recupWare <- recupWare + tempLoop.quantity;
									tempLoop.target <- self.location;
									tempLoop.distance <- tempLoop.distance + tempLoop distance_to self;
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
		my_inter.capacity <- needType1;
		my_inter.stock <- collectType1;
	}
	
	reflex buyingType2 when: not is_built{
		if(priority){
			needType2 <- need - collectType1;
			needType1 <- collectType1;
		}
		if(consumer_strategy=1){
			do buy1Type2;
		}
		if(consumer_strategy=2){
			do buy2Type2;
		}
	}
	
	action buy1Type2 {
		list<Intermediary> temp <- Intermediary where (not(each.is_Consumer) and each.type=2);
		temp <- temp sort_by((each distance_to self) + each.price);
		loop tempInt over: temp{
			if (collect<needType2  and flip(self.probabilitiesProd[tempInt])){
				int collectTemp;
				if(tempInt.is_Producer){
				collectTemp <- min(needType2-collect,tempInt.my_prod.stockMax-tempInt.my_prod.production);
				collect <- collect+collectTemp;
				if(collectTemp>0){
						write self.name + " buy prod Type 2 " + collectTemp;
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
				} else {
					collectTemp <- min(needType2-collect,tempInt.stock);
					collect <- collect+collectTemp;
					if(collectTemp>0){
						write self.name + " buy inter Type 2 " + collectTemp;
						list<Ware> tempWares <- Ware where(each.location = tempInt.location);
						bool endCollecting <- false;
						int recupWare<-0;
						loop tempLoop over: tempWares{
							if(not endCollecting){
								if (recupWare+tempLoop.quantity <= collectTemp) {
									recupWare <- recupWare + tempLoop.quantity;
									tempLoop.target <- self.location;
									tempLoop.distance <- tempLoop.distance + tempLoop distance_to self;
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
		my_inter.capacity <- need;
		my_inter.stock <- collect;
	}
	
	action buy2Type2{
		list<Intermediary> temp <- Intermediary where (not(each.is_Consumer) and each.type=2);
		temp <- temp sort_by((each distance_to self) + each.price);
		loop tempInt over: temp{
			if (collect<needType2 and flip(self.probabilitiesProd[tempInt])){
				int collectTemp;
				if (not(tempInt.is_Producer)and not(tempInt.is_Consumer)){
				collectTemp <- min(needType2-collect,tempInt.stock);
				collect <- collect+collectTemp;
				if(collectTemp>0){
						write self.name + " buy inter Type 2 " + collectTemp;
						list<Ware> tempWares <- Ware where(each.location = tempInt.location);
						bool endCollecting <- false;
						int recupWare<-0;
						loop tempLoop over: tempWares{
							if(not endCollecting){
								if (recupWare+tempLoop.quantity <= collectTemp) {
									recupWare <- recupWare + tempLoop.quantity;
									tempLoop.target <- self.location;
									tempLoop.distance <- tempLoop.distance + tempLoop distance_to self;
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
		my_inter.capacity <- need;
		my_inter.stock <- collect;
	}
	
	aspect base {
		draw square(10) color: prestigious ? #darkblue : #blue;
	}
}

species Intermediary  schedules: shuffle(Intermediary){
	int stock <- 0;
	int capacity <- rnd(capacityInter);
	float price <- 0.0; 
	bool is_Producer; 
	Producer my_prod;
	bool is_Consumer;
	Consumer my_consum;
	int type; //each intermediary is specialised in a type of stone
	
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
		list<Intermediary> temp <- Intermediary where (not(each.is_Consumer));
		temp <- temp sort_by(each distance_to self);
		loop tempInt over: temp{
			if (stock<capacity and collect<capacity){
				int collectTemp;
				if(tempInt.is_Producer){
				collectTemp <- min(capacity-stock,min(capacity,tempInt.stock));
				collect <- collect+collectTemp;
				if(collectTemp>0){
						write name + " buy prod " + collectTemp;
						create Ware number: 1{
							prodPlace <- tempInt.my_prod;
							origin <- tempInt;
							quantity <- collectTemp;
							target <- myself.location;
							distance <- myself distance_to tempInt.my_prod;
						}
						tempInt.stock <- tempInt.stock - collectTemp;
						//tempInt.my_prod.production <- tempInt.my_prod.production + collectTemp;
						stock <- collect;
					}
				}
			}
		}
	}
	
	action buy2 { //buy as a consumer + extra production
		int collect <- 0;
		list<Intermediary> temp <- Intermediary where (not(each.is_Consumer));
		temp <- temp sort_by(each distance_to self);
		loop tempInt over: temp{
			if (stock<capacity and collect<capacity){
				int collectTemp;
				if(tempInt.is_Producer){
					collectTemp <- min(capacity,tempInt.stock); //buying extra production in priority
					collect <- collect+collectTemp;
					stock <- collect;
					
					if(collectTemp>0){
							write "buy prod " + collectTemp;
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
					collectTemp <- min(capacity,tempInt.my_prod.stockMax-tempInt.my_prod.production);
					collect <- collect+collectTemp;
					if(collectTemp>0){
							write "buy prod " + collectTemp;
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
				stock <- collect;
			}
		}
	}
	
	action buy3 { //buy as a consumer
		int collect <- 0;
		list<Intermediary> temp <- Intermediary where (not(each.is_Consumer));
		temp <- temp sort_by(each distance_to self);
		loop tempInt over: temp{
			if (stock<capacity){
				int collectTemp;
				if(tempInt.is_Producer){
				collectTemp <- min(capacity,tempInt.my_prod.stockMax-tempInt.my_prod.production);
				collect <- collect+collectTemp;
				if(collectTemp>0){
						write "buy prod " + collectTemp;
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
		stock <- collect;
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
	int stockMax <- stock_max_prod_fixe ;//+ rnd(stock_max_prod);
	int type; //type 1 is superior to type 2;
	Intermediary my_inter;
	rgb color <- rgb(rnd(255),rnd(255),rnd(255));
	
	reflex produce {
		if producer_strategy=1{
			productionBefore <- production;
			production <- 0;
			stock <- 0;
		}
		if producer_strategy=2{
			productionBefore <- production;
			production <- 0;
			stock <- stockMax-productionBefore;
		}
	}
	
	reflex updateInter{
		//stock represents the extra production left by producers at the previous step
		my_inter.stock<-stock;
	}
	
	aspect base {
			draw triangle(10) color:type=1 ? #darkred : #red;
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
			image "../includes/mapStone.png";
			species PolygonWare;
//			species BackMap aspect:base;
		}

		display distance /*refresh:every(10.0)*/  {
			chart "distance of wares" type: series {
				data "average distance" value: averageDistance color: #green;
				data "distance max" value: distanceMax color: #red;
				data "distance min" value:distanceMin color: #blue;
			}
		}
		
		display "information on consumers" /*type:java2D*/ {
			chart "information on consumers" type:histogram
			style:stack
			{
				loop tempProd over:Producer{
					data tempProd.name style: stack
					value:(Consumer collect each.quantityPerProd[tempProd])
					color: tempProd.color;
				}
			}
		} 
	
		display "production information" {
			chart "production information" type:series size: {0.5,1} position: {0, 0}
			{
				loop tempProd over: Producer {
					data tempProd.name value: tempProd.productionBefore color:tempProd.color;
				}
			}
			chart "stock information" type:series size: {0.5,1} position: {0.5, 0}
			{
				loop tempProd over: Producer {
					data tempProd.name value: tempProd.stock color:tempProd.color;
				}
			}
		} 
	
	}
}

