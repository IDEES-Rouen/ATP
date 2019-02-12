/***
* Name: StoneModel
* Author: mathieu
* Description: adaptation of the meta-model to the case of stone sprading in middle-age
* Tags: Tag1, Tag2, TagN
***/

model StoneModel


global schedules: shuffle(Consumer) + shuffle(Intermediary) + shuffle(Ware) + shuffle(Producer) {
	int nb_init_Consumer <- 2 parameter: true;
	int nb_init_Intermediary <- 1 parameter: true;
	int nb_init_prod <- 2 parameter: true;
	geometry shape <- square(200/*0*/);
	float averageDistance <- 0.0;
	float distanceMax <- 0.0;
	float distanceMin <- 0.0;
	int prodRate <- 5 parameter:true;
	int prodRateFixed <- 50 parameter:true;
	int consumRate <- 50 parameter:true;
	int consumRateFixed <- 500 parameter:true;
	int capacityInter <- 30 parameter: true;
	int stock_max_prod <- 10 parameter: true;
	int stock_max_prod_fixe <- 100 parameter: true;
	float init_price <- 100.0 parameter: true;
	
	int consumer_strategy <- 1 parameter: true min: 1 max: 2; //1:buy to producers and intermediaries. 2:only buy to inermediairies.
	int intermediary_strategy <- 1 parameter: true min:1 max: 3; //1: buy the stock. 2: buy stock and place orders. 3: only place orders.
	int producer_strategy <- 1 parameter: true min: 1 max: 2; //1: produce just what has been oredered. 2: produce the maximum it can
	
	//TODO : create consumers, intermediaries and producers with different types and different money/price
	init {
		do createProd(nb_init_prod);
		do createInter(nb_init_Intermediary);
		do createConsum(nb_init_Consumer);
	}
	
	user_command "create consum"{
		do createConsum(1);
	}
	
	user_command "destroy consum"{
		do destroyConsum;
	}
	
	user_command "create prod"{
		do createProd(1);
	}
	
	user_command "destroy prod"{
		do destroyProd;
	}
	
	user_command "create inter"{
		do createInter(1);
	}
	
	user_command "destroy inter"{
		do destroyInter;
	}
	
	action createConsum(int nb_conso){
		create Consumer number: nb_conso{
			create Intermediary number: 1{
				location <-myself.location;
				is_Consumer <- true;
				my_consum <- myself;
				is_Producer <- false;
				my_prod <- nil;
				capacity <- myself.need;
				stock <- myself.collect;
				money <- myself.money;
				
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
	
	action createProd(int nb_prod){
		create Producer number: nb_prod{
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
	
	action createInter(int nb_inter){
		create Intermediary number: nb_inter{
			is_Producer <- false;
			my_prod <- nil;
			is_Consumer <- false;
			my_consum <- nil;
			capacity <- rnd(capacityInter);
			price <- init_price;
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
					if ((tempProd !=nil) and bool(tempConsum.presenceProd[tempProd])){
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

species Consumer {
	//TODO //diversify with types of ware and use of "money"
	int money;
	int need <- consumRateFixed + rnd(consumRate) ;
	int collect <- 0 ;
	Intermediary my_inter; 
	list<Ware> wareReceived <- nil;
	map presenceProd;
	
	bool is_built<-false;
	int time_to_be_built <- 0;
	
	init {
		loop temp over: Producer{
			add temp::false to:presenceProd;
		}
	}
	
	reflex updateInterStart{
		my_inter.capacity <- need;
		my_inter.stock <- collect;
	}
	
	reflex updateConstruit when:not is_built{
		if(collect>=need){
			is_built <- true;
			write self.name + " est construit";
		}
		time_to_be_built <- time_to_be_built +1;
	}
	
	//TODO add money in the computation
	reflex buying when: not is_built{
		if(consumer_strategy=1){
			do buy1;
		}
		if(consumer_strategy=2){
			do buy2;
		}
	}
	
	action buy1 {
		list<Intermediary> temp <- Intermediary where (not(each.is_Consumer));
		temp <- temp sort_by((each distance_to self) + each.price);
		loop tempInt over: temp{
			if (collect<need){
				int collectTemp;
				if(tempInt.is_Producer){
				collectTemp <- min(need,tempInt.my_prod.stockMax-tempInt.my_prod.production);
				collect <- collect+collectTemp;
				if(collectTemp>0){
						write "buy prod " + collectTemp;
						create Ware number: 1{
							prodPlace <- tempInt.my_prod;
							origin <- tempInt;
							quantity <- collectTemp;
							target <- myself.location;
							distance <- myself distance_to tempInt.my_prod;
							put true at:self.prodPlace in: myself.presenceProd;
						}
						//tempInt.stock <- tempInt.stock - collectTemp;
						tempInt.my_prod.production <- tempInt.my_prod.production + collectTemp;
					}
				} else {
					collectTemp <- min(need,tempInt.stock);
					collect <- collect+collectTemp;
					if(collectTemp>0){
						write "buy inter " + collectTemp;
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
	
	action buy2{
		list<Intermediary> temp <- Intermediary where (not(each.is_Consumer));
		temp <- temp sort_by((each distance_to self) + each.price);
		loop tempInt over: temp{
			if (collect<need){
				int collectTemp;
				if (not(tempInt.is_Producer)and not(tempInt.is_Consumer)){
				collectTemp <- min(need,tempInt.stock);
				collect <- collect+collectTemp;
				if(collectTemp>0){
						write "buy inter " + collectTemp;
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
	int money;
	
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
				draw circle(stock) color:#green;
			} else {
				draw circle(1) color:#green;
			}	
		}
	}
}

species Producer{
	int production <- 0 ;
	int productionBefore;
	int stock <- 0 ;
	int stockMax <- stock_max_prod_fixe ;//+ rnd(stock_max_prod);
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
			draw triangle(10) color:#red;
	}
}

species Ware{
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
			species Consumer aspect:base;
			species Intermediary aspect:base;
			species Producer aspect:base;
			species Ware;
			species PolygonWare transparency: 0.5;
		}

		display second_display background: #lightgray {
			species PolygonWare;
		}

		display distance /*refresh:every(10.0)*/  {
			chart "distance of wares" type: series {
				data "average distance" value: averageDistance color: #green;
				data "distance max" value: distanceMax color: #red;
				data "distance min" value:distanceMin color: #blue;
			}
		}
	//TODO : display percentage of producer per consumer
		display "production information" {
			chart "production information" type:histogram size: {0.5,1} position: {0, 0}
			{
				loop tempProd over: Producer {
					data tempProd.name value: tempProd.productionBefore;
				}
			}
			chart "stock information" type:histogram size: {0.5,1} position: {0.5, 0}
			{
				loop tempProd over: Producer {
					data tempProd.name value: tempProd.stock;
				}
			}
		} 
	
	}
}

