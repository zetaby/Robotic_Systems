function [bot, botGhost_mean, botGhost_mode] = ParticleFilter(bot, modifiedMap,numParticles, maxNumOfIterations, scans, target)
%UNTITLED Summary of this function goes here
%   Detailed explanation goes here

    sensorNoise = 1.363160109; % from robot calibration - 0;%
    motionNoise = 0.012088592; % from robot calibration - 0;%
    turningNoise = toRadians('degrees', 5.444208795); % from robot calibration - 0;%
        turnBot =pi/4;
        
%generate some random particles inside the map
num =numParticles; % number of particles
particles(num,1) = BotSim; %how to set up a vector of objects
for i = 1:num 
    particles(i) = BotSim(modifiedMap, [ sensorNoise, motionNoise, turningNoise ], 0);  %each particle should use the same map as the botSim object
    particles(i).randomPose(10); %spawn the particles in random locations
    particles(i).setScanConfig(particles(i).generateScanConfig(scans));
end

n = 0;
converged =0; %The filter has not converged yet
while(converged == 0 && n < maxNumOfIterations) %%particle filter loop
    n = n+1; %increment the current number of iterations
    
    botScan = bot.ultraScan() %get a scan from the real robot.
    
    while (botScan < 0) 
        bot.turn(turnBot);
        
        for i=1:num
           particles(i).turn(turnBot); 
        end
        botScan = bot.ultraScan() %get a scan from the real robot.
    end
    
    %% Write code for updating your particles scans
    particlesScan = zeros(scans,num);
    difference = zeros(scans,num);
    weight = zeros(num,1);
    particle_weight = zeros(scans,1);
    var = 50;
    k = 0; %damping factor
    for i=1:num
        if particles(i).insideMap() ==0
            particles(i).randomPose(0);
        end
        particlesScan(:,i)= particles(i).ultraScan();
        for j=1:scans
            %% Write code for scoring your particles
            p = circshift(particlesScan(:,i),j); %shift the scans to allow for different orientations
            difference(j,i) = sqrt(sum((p-botScan).^2)); %difference is Euclidean distance between scan vectors
            particle_weight(j) = k + (1/sqrt(2*pi*var))*exp(-((difference(j,i))^2/(2*var)));
        end
        [max_weight, max_pos] = max(particle_weight);
        weight(i) = max_weight;
        particles(i).turn(max_pos*2*pi/scans);
    end
        
    %now need to normalise
    weights = weight./sum(weight);
    
    positions = zeros(num, 2);
    pos_diffs = zeros(num, 1);
    
    for i = 1:num

        positions(i,:) = particles(i).getBotPos();

    end
    
    %% Write code for resampling your particles
    
    newParticleLocations = zeros(num, 3);
    
    for i = 1:num
        j = find(rand() <= cumsum(weights),1);
        newParticleLocations(i, 1:2) = particles(j).getBotPos();
        newParticleLocations(i, 3) = particles(j).getBotAng();
    end
     
    R=2;
  
    for i=1:num
        t = 2*pi*rand();
        r=R*sqrt(rand());
        particles(i).setBotPos([newParticleLocations(i,1)+r.*cos(t), newParticleLocations(i,2) + r.*sin(t)]);
        particles(i).setBotAng(newParticleLocations(i,3));
    end
               
    
    %% Write code to check for convergence   
    
    % TODO accept this as a parameter?
    convergencethreshold = 2;
   
    % obtain particle positions
    for j = 1:num
        positions(j,:) = particles(j).getBotPos();
    end
   
    % compute standard deviations of particle positions (in x and y
    % coordinates)
    stdev = std(positions);
   
    % particle filter has converged if standard deviations are below
    % convergence threshold
    if stdev < convergencethreshold
        converged = 1;
    end
    
    %% Estimating particle position

    angles = zeros(num,1);
    for i=1:num
        angles(i)=particles(i).getBotAng();
    end    
       
    particles_mean_est = BotSim(modifiedMap, [ sensorNoise, motionNoise, turningNoise ], 0);
    particles_mean_est.setScanConfig(particles_mean_est.generateScanConfig(scans));
    particles_mean_est.setBotPos(mean(positions));
    particles_mean_est.setBotAng(mean(angles));
    
    particles_mode_est = BotSim(modifiedMap, [ sensorNoise, motionNoise, turningNoise ], 0);
    particles_mode_est.setScanConfig(particles_mode_est.generateScanConfig(scans));
    particles_mode_est.setBotPos(mode(round(positions)));
    particles_mode_est.setBotAng(mode(round(angles))); % particles_mode_est.setBotAng(mode(round(angles, 2)));

    %% Write code to take a percentage of your particles and respawn in randomised locations (important for robustness)	
    
    mutation_rate=0.1;
    
    mutation_index = ceil(num.*rand(mutation_rate*num,1));
    
    for i=1:mutation_rate*num
        particles(mutation_index(i)).randomPose(0);
    end 
    
    %% Write code to decide how to move next
    % here they just turn in cicles as an example

    botScanFront = bot.getDistance_cm();

    while (botScanFront < 0)
         
        bot.turn(turnBot);
        for i=1:num
            particles(i).turn(turnBot);
        end
        
        botScanFront = bot.getDistance_cm();
    end

    if (botScanFront > 30)
        move = botScanFront*0.3; % potentially use small fixed increment
    else
        move = 0;
    end
        
    turn = pi/2;
    
    bot.move(move); %move the real robot. These movements are recorded for marking 
    bot.turn(turn);

    for i =1:num %for all the particles.
        particles(i).move(move); %move the particle in the same way as the real robot
        particles(i).turn(turn); %turn the particle in the same way as the real robot

    end
    
    particles_mean_est.move(move);    
    particles_mean_est.turn(turn);

    particles_mode_est.move(move);   
    particles_mode_est.turn(turn);

    
    %% Drawing
    figure(3)
    hold off; %the drawMap() function will clear the drawing when hold is off
    particles(1).drawMap();
    for i =1:num
        particles(i).drawBot(3); %draw particle with line length 3 and default color
    end
    particles_mean_est.drawBot(30, 'r');
    particles_mode_est.drawBot(30, 'b');
    drawnow;

    botGhost_mean = particles_mean_est;
    botGhost_mode = particles_mode_est;

end

botScan = bot.ultraScan();
difference_mean= [360,1];
difference_mode= [360,1];
for i=1:360    
    botGhost_meanScan = botGhost_mean.ultraScan();
    botGhost_modeScan = botGhost_mode.ultraScan();
    difference_mean(i) = norm(botGhost_meanScan-botScan);
    difference_mode(i) = norm(botGhost_modeScan-botScan);
    botGhost_mean.setBotAng(i*pi/180);
    botGhost_mode.setBotAng(i*pi/180);
end

    [min_weight_mean, min_pos_mean] = min(difference_mean);
    botGhost_mean.setBotAng(min_pos_mean*pi/180); 
    [min_weight_mode, min_pos_mode]=min(difference_mode);
    botGhost_mode.setBotAng(min_pos_mode*pi/180);
    
    figure(3)
    hold off; %the drawMap() function will clear the drawing when hold is off
    particles(1).drawMap();

    botGhost_mean.drawBot(30, 'r');
    botGhost_mode.drawBot(30, 'b');
    
    plot(target(1),target(2),'Marker','o','Color','g');
    drawnow;
end

