/***
* Name: MetaModel
* Author: mathieu
* Description: general model for the spreading of wares
* Tags: Tag1, Tag2, TagN
***/

model MetaModel

global schedules: shuffle(Consumer) + shuffle(Intermediary) + shuffle(Ware) + shuffle(Producer){
	int nb_init_Consumer <- 2 parameter: true;
	int nb_init_Intermediary <- 1 parameter: true;
	int nb_init_prod <- 2 parameter: true;
	geometry shape <- square(200/*0*/);
	float averageDistance <- 0.0;
	float distanceMax <- 0.0;
	float distanceMin <- 0.0;
	int prodRate <- 5 parameter:true;
	int prodRateFixed <- 50 parameter:true;
	int consumRate <- 5 parameter:true;
	int consumRateFixed <- 50 parameter:true;
	int capacityInter <- 30 parameter: true;
	int stock_max_prod <- 10 parameter: true;
	int stock_max_prod_fixe <- 100 parameter: true;
	float init_price <- 100.0 parameter: true;
	
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
	
	action createConsum(int nb_consum){
		create Consumer number: nb_consum{
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
	
}

species Consumer {
	//TODO //diversify with types and money
	int money;
	int need <- consumRateFixed + rnd(consumRate) update:consumRateFixed + rnd(consumRate) ; //in the stone case, need represents a total need (it is not updated).
	int collect <- 0 update: 0; //the update to 0 represent the consumption of all that has been collected.
	Intermediary my_inter; 
	list<Ware> wareReceived <- nil;
	map presenceProd;
	
	bool is_built; //used to stop the collect
	
	init {
		loop temp over: Producer{
			add temp::false to:presenceProd;
		}
	}
	
	reflex updateInterStart{
		my_inter.capacity <- need;
		my_inter.stock <- collect;
	}
	
	reflex buying { //buying to all the intermediairies which are not consumer
//		do buy0;
		do buy1; //replace depending on the method tested
//		do buy2;
	}
	
	action buy0{
		//random choice
		loop tempInt over: shuffle(Intermediary where (not(each.is_Consumer))){
			if (collect<need){
				int collectTemp;
				collectTemp <- min(need,tempInt.stock);
				collect <- collect+collectTemp;
				if(tempInt.is_Producer){
					write "buy prod " + collectTemp;
				} else {
					write "buy inter " + collectTemp;
				}
				ask tempInt{
					stock <- stock - collectTemp;
				}
			}
		}
		my_inter.capacity <- need;
		my_inter.stock <- collect;
	}
	
	action buy1 { //buy the maximum in quantity, with a price added by intermediaries
		list<Intermediary> temp <- Intermediary where (not(each.is_Consumer));
		temp <- temp sort_by((each distance_to self)+each.price); //distance_to is applied to the topology of the calling agent
		loop tempInt over: temp{
			if (collect<need){
				int collectTemp;
				collectTemp <- min(need,tempInt.stock);
				collect <- collect+collectTemp;
				if(collectTemp>0){
					if(tempInt.is_Producer){
						write "buy prod " + collectTemp;
						create Ware number: 1{
							prodPlace <- tempInt.my_prod;
							origin <- tempInt;
							quantity <- collectTemp;
							target <- myself.location;
							distance <- myself distance_to tempInt.my_prod;
							put true at:self.prodPlace in: myself.presenceProd;
						}
					} else {
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
	
	action buy2{ // buy to the farthest
		list<Intermediary> temp <- Intermediary where (not(each.is_Consumer));
		temp <- temp sort_by(1/each distance_to self); //On peut mettre des expressions dans le sort_by.
		loop tempInt over: temp{
			if (collect<need){
				int collectTemp;
				collectTemp <- min(need,tempInt.stock);
				collect <- collect+collectTemp;
				if(tempInt.is_Producer){
					write "buy prod " + collectTemp;
				} else {
					write "buy inter " + collectTemp;
				}
				ask tempInt{
					stock <- stock - collectTemp;
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
		if (stock>0){
			draw triangle(stock) color:#red;
		}else {
			draw triangle(1) color:#red;
		}
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
		
		display chart /*refresh:every(10.0)*/  {
			chart "distance of wares" type: series {
				data "average distance" value: averageDistance color: #green;
				data "distance max" value: distanceMax color: #red;
				data "distance min" value:distanceMin color: #blue;
			}
		}
	
	}
}