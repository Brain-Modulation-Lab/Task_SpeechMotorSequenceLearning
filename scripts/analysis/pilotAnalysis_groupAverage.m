function pilotAnalysis_average

subjects = ['pilot001';'pilot002';'pilot003';'pilot004';...
    'pilot005';'pilot006';'pilot007'];

numSubj = 7;

illegal_ends = zeros(1,60);
legal_ends = zeros(1,60);

illegal_errors = zeros(1,60);
legal_errors = zeros(1,60);


for mm = 1:numSubj
    subjects(mm,:)
    [ends, errors] = pilotAnalysis_part2(subjects(mm,:));
    illegal_ends = vertcat(illegal_ends, ends(1,:));
    legal_ends = vertcat(legal_ends, ends(2,:));
    illegal_errors = vertcat(illegal_errors, errors(1,:));
    legal_errors = vertcat(legal_errors, errors(2,:));
end

illegal_ends = illegal_ends(2:end,:);
legal_ends = legal_ends(2:end,:);

illegal_errors = illegal_errors(2:end,:);
legal_errors = legal_errors(2:end,:);

illegal_ends_means = zeros(1,60);

for ii = 1:60
    temp = [];
    temp_count = 0;
    for jj = 1:numSubj
        if illegal_ends(jj,ii) > 0
            temp = vertcat(temp,illegal_ends(jj,ii));
            temp_count = temp_count + 1;
        end
    end
    illegal_ends_means(ii) = sum(temp)/temp_count;
end
legal_ends_means = mean(legal_ends);

illegal_errors_means = mean(illegal_errors);
legal_errors_means = mean(legal_errors);

subplot(2,1,1);
hold on; plot((1:length(illegal_ends_means)),illegal_ends_means,'-r','LineWidth',2);
hold on; plot((1:length(legal_ends_means)),legal_ends_means,'-b','LineWidth',2);

title('Utterance Duration');
ylabel('msec')
% 
% % title('Percent decrease in initial utterance duration');
% % ylabel('Percent decrease');
% % plot((1:50),zeros(1,50),'--c');
% axis([1 50 -.1 .2])

% title('% of Target Utterance Duration');
% plot((1:60),zeros(1,60)+1,'--c');

subplot(2,1,2); hold on; plot((1:60),illegal_errors_means,'-r','LineWidth',2);
hold on; plot((1:60),legal_errors_means,'-b','LineWidth',2);
title('Accuracy');
ylabel('Percent Errors');
axis([1 60 0 1.1])
% plot((1:60),zeros(1,60)+1,'--c');
% ylabel('Percent correct');
% xlabel('Repetition');

% hold off;
% newplot;
% plot((1:length(illegal_ends_means)),illegal_ends_means*1000,'-k','LineWidth',2);
% hold on; plot((1:length(legal_ends_means)),legal_ends_means*1000,'-k');
% % plot((1:60),illegal_errors_means,'-k','LineWidth',2);
% % hold on; plot((1:60),legal_errors_means,'-k');
% % plot((1:60),zeros(1,60),'--c');
% % axis([1 60 -0.05 .6])
% xlabel('Trials')
% ylabel('Reaction time (msec)');