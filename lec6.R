# 安装和加载包
options(repos = c(CRAN = "https://mirrors.tuna.tsinghua.edu.cn/CRAN/"))
if (!requireNamespace('pacman', quietly = TRUE)) {
  install.packages('pacman')
}
pacman::p_load("tidyverse","ggplot2", "dplyr","gridExtra","papaja", "patchwork","bayesplot","rstan")
options(warn = -1)  # 抑制警告
# 设置 x 的范围为 [2, 10]
x_range <- seq(2, 10, length.out = 1000)

# 计算正态分布的概率密度函数
y_norm <- dnorm(x_range, mean = 6.25, sd = 0.75)

# 对正态分布进行采样，得到1000个样本值
samples <- rnorm(1000, mean = 6.25, sd = 0.75)

# 显示前 10 个样本值
cat("前 10 个样本值：", head(samples, 10))

# 绘制图像
options(repr.plot.width=10, repr.plot.height=6) 
df <- data.frame(x = x_range, y = y_norm)
ggplot2::ggplot(df, aes(x = x, y = y)) +
  ggplot2::geom_histogram(aes(x = samples, y = ..density..),  bins = 45, fill = "lightgrey", color = "black") +
  ggplot2::geom_line(color = 'red', size = 1.5)+ 
  ggplot2::scale_y_continuous(expand = c(0, 0) , limits = c(0, 0.55)) +
  papaja::theme_apa()

#===========================================================================
#                  心情示例：状态转移（Markov Chain）
#===========================================================================

# 中文字体：选一个系统里有中文字形的（跨平台回退；都找不到则用设备默认）
cjk <- if (requireNamespace("systemfonts", quietly = TRUE)) {
  intersect(c("PingFang SC", "Heiti SC", "Songti SC", "STHeiti", "Hiragino Sans GB",
              "Microsoft YaHei", "SimHei", "Noto Sans CJK SC", "WenQuanYi Micro Hei"),
            systemfonts::system_fonts()$family)[1]
} else NA
if (is.na(cjk)) cjk <- ""

# 状态转移矩阵 P：行 = 前一天(n-1)，列 = 当天(n)
P <- matrix(c(0.5, 0.25, 0.25,
              0.5, 0,    0.5,
              0.25, 0.25, 0.5),
            nrow = 3, byrow = TRUE,
            dimnames = list(c("开心", "冷静", "悲伤"),
                            c("开心", "冷静", "悲伤")))
emo <- c("开心", "冷静", "悲伤")
n_days <- 1000

# 从 start 出发，按照 P 转移 n_days 次（每次 = 一天）
set.seed(202409)
sim_mood <- function(start, n) {
  s <- character(n + 1)
  s[1] <- start
  for (i in 1:n) s[i + 1] <- sample(emo, 1, prob = P[s[i], ])
  s
}

# 分别以三种情绪为起点，各模拟一条链
chains <- lapply(emo, sim_mood, n = n_days)
names(chains) <- emo

# 出现频率
freq <- do.call(rbind, lapply(emo, function(st)
  data.frame(起点 = st, 情绪 = emo,
             freq = as.numeric(table(factor(chains[[st]], levels = emo))) / (n_days + 1))))

# 累计频率
cum <- do.call(rbind, lapply(emo, function(st)
  do.call(rbind, lapply(emo, function(e)
    data.frame(起点 = st, 情绪 = e, day = 1:(n_days + 1),
               cumfreq = cumsum(chains[[st]] == e) / (1:(n_days + 1)))))))

pi_df <- data.frame(情绪 = emo, freq = c(0.4, 0.2, 0.4))

# 上排：出现频率（灰虚线 = 理论平稳分布）
bar_plot <- ggplot(freq, aes(情绪, freq)) +
  geom_col(fill = "#6497b1") +
  geom_text(aes(label = sprintf("%.2f", freq)), vjust = -0.4, size = 3) +
  geom_line(data = pi_df, aes(情绪, freq, group = 1), linetype = "dashed", color = "grey30") +
  geom_point(data = pi_df, aes(情绪, freq), shape = 18, size = 3, color = "grey30") +
  facet_wrap(~ 起点) + ylim(0, 0.5) +
  labs(x = NULL, y = "频率") + papaja::theme_apa(base_family = cjk)

# 下排：累计频率随天数变化
cum_plot <- ggplot(cum, aes(day, cumfreq, color = 情绪)) +
  geom_line() +
  geom_hline(data = pi_df, aes(yintercept = freq, color = 情绪),
             linetype = "dashed", show.legend = FALSE) +
  facet_wrap(~ 起点) + ylim(0, 1) +
  labs(x = "天数", y = "累计频率") + papaja::theme_apa(base_family = cjk)

# 将两个图上下排列显示
options(repr.plot.width=16, repr.plot.height=7) 
bar_plot / cum_plot

set.seed(2024)

current <- 3                             # 假设theta^n为3

proposal <- rnorm(1, mean = current, sd = 1)    # 从当前正态分布中抽出一个样本

cat("从建议分布中新采样 θ(n+1)为：",proposal)
# 设置先验
proposal_prior <- dnorm(proposal, mean = 3, sd = 1)  # 先验概率密度
current_prior <- dnorm(current, mean = 3, sd = 1)    # 先验概率密度

# 定义似然函数
likelihood <- function(theta) {
  Y <- 6  # 假设数据 Y 为 6
  return(dnorm(Y, mean = theta, sd = 0.75))  # 固定 sd=0.75
}

# 计算建议位置的未归一化的后验概率值（先验 * 似然）
proposal_posterior <- proposal_prior * likelihood(proposal)

# 计算当前位置的未归一化的后验概率值（先验 * 似然）
current_posterior <- current_prior * likelihood(current)

# 计算接受概率α，为两者概率值之比
alpha <- min(1, proposal_posterior / current_posterior)

# 打印出接受概率α
cat("后验比为：", proposal_posterior / current_posterior, ", alpha为:", alpha, "\n")

# 根据接受概率α进行抽样，抽样内容为建议位置和当前位置
next_stop <- sample(c(proposal, current), 1, prob = c(alpha, 1 - alpha))

# 打印出下一个位置的值
cat("下一个位置的值为:", next_stop, "\n")
# 从第一段代码我们可以看到此时的接受概率α=1，因此接受了建议值作为我们的下一个值

one_mh_iteration <- function(current, sigma = 1) {
  
  # 提议值:从均值为current，方差为sigma（默认值为1）的正态分布中抽样
  proposal <- rnorm(1, mean = current, sd = sigma)
  
  # 设置先验并计算概率密度
  proposal_prior <- dnorm(proposal, mean = 3, sd = 1)
  current_prior <- dnorm(current, mean = 3, sd = 1)
  
  # 定义似然函数
  likelihood <- function(theta) {
    Y <- 6  # 假设数据 Y 为 6
    return(dnorm(Y, mean = theta, sd = 0.75))  # 计算似然
  }
  
  # 计算未归一化的后验概率
  proposal_posterior <- proposal_prior * likelihood(proposal)
  current_posterior <- current_prior * likelihood(current)
  
  # 计算接受概率 alpha
  if (is.na(proposal_posterior) || is.na(current_posterior) || current_posterior <= 0) {
    alpha <- 0
  } else {
    alpha <- min(1, proposal_posterior / current_posterior)
  }
  
  # 根据接受概率 alpha 进行抽样
  next_stop <- sample(c(proposal, current), 1, prob = c(alpha, 1 - alpha), replace = TRUE)
  
  # 返回建议值、接受概率和下一个位置组成的数据框
  result <- data.frame(proposal = proposal, alpha = alpha, next_stop = next_stop)
  
  return(result)
}

# 设置随机种子
set.seed(2024)

# 调用函数并显示结果
results <- one_mh_iteration(current = 3)
print(results, row.names = FALSE) 

# 变换不同的随机数种子，其实也是生成不同的建议值
set.seed(83)

# 调用函数并显示结果
results <- one_mh_iteration(current = 3)
print(round(results, digits = 4), row.names = FALSE) #用round对数据框内数字四舍五入，保留4位小数

mh_tour <- function(N, sigma = 1) {
  current <- 3
  mu <- numeric(N)  # 创建一个长度为 N 的零向量
  
  # 循环进行 N 次迭代
  for (i in 1:N) {
    sim <- one_mh_iteration(current, sigma)  # 调用采样函数
    mu[i] <- sim$next_stop  # 保存当前的下一个位置
    current <- sim$next_stop  # 更新当前值
  }
  
  # 返回包含迭代次数和每次采样结果的数据框
  result <- data.frame(iteration = 1:N,mu = mu)
  
  return(result)
}

# 调用定义好的函数，将采样次数设为5000
set.seed(84735)
mh_simulation <- mh_tour(N=5000)
tail(mh_simulation, n = 5)

# 绘制密度图
density_plot <- ggplot2::ggplot(mh_simulation, aes(x = mu)) +
  ggplot2::geom_histogram(aes(y = ..density..), 
                          bins = 30, 
                          color = "white", 
                          fill = "darkgrey", 
                          alpha = 0.7) +
  ggplot2::geom_density(aes(y = ..density..), 
                        color = "#6497b1", 
                        size = 1) +
  ggplot2::labs(x = "mu", y = "density") +
  papaja::theme_apa()  + 
  ggplot2::scale_y_continuous(expand = c(0, 0) , limits = c(0, 0.7)) 

# 绘制轨迹图
trace_plot <- ggplot2::ggplot(mh_simulation, aes(x = iteration, y = mu)) +
  ggplot2::geom_line(color = "#6497b1") +
  ggplot2::labs(x = "iteration", y = "mu") +
  papaja::theme_apa()  + 
  ggplot2::scale_y_continuous(limits = c(3, 9)) 

# 将两个图并排显示
options(repr.plot.width=16, repr.plot.height=7) 
density_plot + trace_plot

#创建绘图数据框
sample <- as.data.frame(mh_simulation$mu)

#采样密度图
dens <- bayesplot::mcmc_dens(sample) +    
  ggplot2::labs(x = "mu", y = "density") +
  papaja::theme_apa()

#采样轨迹图
trace <- bayesplot::mcmc_trace(sample) +  
  ggplot2::labs(x = "iteration", y = "density") +
  papaja::theme_apa()

dens + trace

one_mh_iteration <- function(current, sigma = 1) {
  
  # 提议值:从均值为current，方差为sigma（默认值为1）的正态分布中抽样
  proposal <- rnorm(1, mean = current, sd = sigma)
  
  # 设置先验并计算概率密度
  proposal_prior <- dnorm(proposal, mean = 3, sd = 1)
  current_prior <- dnorm(current, mean = 3, sd = 1)
  
  # 定义似然函数
  likelihood <- function(theta) {
    Y <- 6  # 假设数据 Y 为 6
    return(dnorm(Y, mean = theta, sd = 0.75))  # 计算似然
  }
  
  # 计算未归一化的后验概率
  proposal_posterior <- proposal_prior * likelihood(proposal)
  current_posterior <- current_prior * likelihood(current)
  
  # 计算接受概率 alpha
  if (is.na(proposal_posterior) || is.na(current_posterior) || current_posterior <= 0) {
    alpha <- 0
  } else {
    alpha <- min(1, proposal_posterior / current_posterior)
  }
  
  # 根据接受概率 alpha 进行抽样
  next_stop <- sample(c(proposal, current), 1, prob = c(alpha, 1 - alpha), replace = TRUE)
  
  # 返回建议值、接受概率和下一个位置组成的数据框
  result <- data.frame(proposal = proposal, alpha = alpha, next_stop = next_stop)
  
  return(result)
}

mh_tour <- function(N, sigma = 1) {
  current <- 3
  mu <- numeric(N)  # 创建一个长度为 N 的零向量
  
  # 循环进行 N 次迭代
  for (i in 1:N) {
    sim <- one_mh_iteration(current, sigma)  # 调用采样函数
    mu[i] <- sim$next_stop  # 保存当前的下一个位置
    current <- sim$next_stop  # 更新当前值
  }
  
  # 返回包含迭代次数和每次采样结果的数据框
  result <- data.frame(iteration = 1:N,mu = mu)
  
  return(result)
}

#===========================================================================
#                            请修改 sigma 的值。
#===========================================================================
set.seed(84735)
mh_simulation = mh_tour(N=5000, sigma=1)
#创建绘图数据框
sample_x <- as.data.frame(mh_simulation$mu)

#采样密度图
dens_x <- bayesplot::mcmc_dens(sample_x) +    
  ggplot2::labs(x = "mu", y = "density") +
  papaja::theme_apa()

#采样轨迹图
trace_x <- bayesplot::mcmc_trace(sample_x) +  
  ggplot2::labs(x = "iteration", y = "density") +
  ggplot2::scale_y_continuous(limits = c(2.5, 9)) +
  papaja::theme_apa()

dens_x + trace_x

##Stan实战
# 准备数据
stan_data <- list(n = 10,Y = 9)
# 使用Stan语法建构模型
stan_model_code <- "
data {  //数据块
  int<lower=0> n;       // 试验次数
  int<lower=0, upper=n> Y;  // 成功次数
}

parameters {  //参数块
  real<lower=0, upper=1> pi;    // 成功概率参数
}

model {  //模型块
  // 设置先验
  pi ~ beta(2, 2);
  
  // 设置似然
  Y ~ binomial(n, pi);
}
"
# 拟合模型
trace <- rstan::stan(
  model_code = stan_model_code,      # 定义的模型或模型文件路径
  data = stan_data,                  # 输入数据
  chains = 2,                        # 马尔可夫链数量
  iter = 2000,                       # 总迭代次数（每个链）
  warmup = 1000,                     # 热身迭代次数（不保存）
  seed = 202409
)

#创建绘图数据框
idata <- rstan::extract(trace)
sample_pi <- as.data.frame(idata$pi)
#采样密度图
dens_pi <- bayesplot::mcmc_dens(sample_pi) +    
  ggplot2::labs(x = "pi", y = "density") +
  papaja::theme_apa()
# 绘制轨迹图
trace_pi <- rstan::traceplot(trace,color = '#6497b1')

dens_pi + trace_pi

# 选取第一条Makov链的前20个采样结果和前200个结果
sample_pi_20 <- as.data.frame(sample_pi[1:20, ])
sample_pi_200 <- as.data.frame(sample_pi[1:200, ])

# 绘图
options(repr.plot.width=16, repr.plot.height=5) 
#前20
dens_20 <- bayesplot::mcmc_dens(sample_pi_20) +    
  ggplot2::labs(x = "pi", y = "density") +
  papaja::theme_apa()
trace_20 <- bayesplot::mcmc_trace(sample_pi_20) +  
  ggplot2::labs(x = "pi", y = NULL) +
  papaja::theme_apa() 
dens_20 + trace_20

#前200
dens_200 <- bayesplot::mcmc_dens(sample_pi_200) +    
  ggplot2::labs(x = "pi", y = "density") +
  papaja::theme_apa()
trace_200 <- bayesplot::mcmc_trace(sample_pi_200) +  
  ggplot2::labs(x = "pi", y = NULL) +
  papaja::theme_apa() 
dens_200 + trace_200

rbind(head(sample_pi, 5), tail(sample_pi, 5))

x <- seq(0.2, 1, length.out = 10000)
# 真实的后验分布 beta（alpha + y, beta + n - y）
y <- dbeta(x, 11, 3)
posterior_data <- data.frame(x = x, y = y)

#绘制采样结果直方图
hist_pi <- bayesplot::mcmc_hist(sample_pi, bins=30) +    
  ggplot2::labs(x = "pi", y = "count") +
  papaja::theme_apa()

#绘制采样结果分布图和真实后验分布图
dens_pi_mix <- bayesplot::mcmc_dens(sample_pi) +  #采样结果
  ggplot2::geom_line(data = posterior_data, aes(x = x, y = y), color = "black",size = 0.8) +  #真实后验
  ggplot2::labs(x = "pi", y = "density") +
  papaja::theme_apa()

hist_pi + dens_pi_mix 

##练习（完整代码）
#===========================================================================
#                            请修改 ... 中的值。
#===========================================================================

#准备数据
data_list <- list(
  Y = c(320, 310, 280, 340, 300), # 观测数据
  n = 5                          # 观测数据的数量
)

#构建模型

stan_code <- "
data {
  int<lower=0> n;           // 观测数据的数量
  vector[n] Y;              // 观测数据
}

parameters {
  real mu;                  // 反应时间均值
}

model {
  // 先验分布
  mu ~ normal(300, 50);

  // 似然函数
  Y ~ normal(mu, 20);
}
"
#===========================================================================
#                            请修改 ... 中的值。
#===========================================================================
trace <- rstan::stan(
  model_code = stan_code,            # 定义的模型或模型文件路径
  data = data_list,                  # 输入数据
  chains = 4,                        # 马尔可夫链数量
  iter = 2000,                       # 总迭代次数
  warmup = 1000,                     # 热身迭代次数
  seed = 202409
)

#创建绘图数据框
idata <- rstan::extract(trace)
sample_mu <- as.data.frame(idata$mu)
#采样密度图
dens_mu <- bayesplot::mcmc_dens(sample_mu) +    
  ggplot2::labs(x = "mu_prior", y = "density") +
  papaja::theme_apa()
# 绘制轨迹图
trace_mu <- rstan::traceplot(trace,color = '#6497b1')

dens_mu + trace_mu

#===========================================================================
#                            为了和真实的后验分布进行比较，计算真实的后验分布。
#===========================================================================


# 先验分布的均值和标准差
mu_prior <- 300  # 先验均值
sigma_prior <- 50  # 先验标准差

# 观测数据的标准差 (已知)
sigma_obs <- 20

# 假设观测数据
observed_data <- c(320, 310, 280, 340, 300)  # 替换为实际观测数据

# 计算观测数据的数量和均值
n <- length(observed_data)  
y_mean <- mean(observed_data)  

# 计算后验分布的均值和方差
posterior_mean <- (sigma_obs^2 * mu_prior + n * sigma_prior^2 * y_mean) / (n * sigma_prior^2 + sigma_obs^2)
posterior_variance <- (sigma_prior^2 * sigma_obs^2) / (n * sigma_prior^2 + sigma_obs^2)
posterior_std <- sqrt(posterior_variance)

# 输出结果
cat("后验分布的均值:", posterior_mean)
cat("后验分布的标准差:", posterior_std)

# 计算真实的后验分布
x <- seq(200, 400, length.out = 5000)  # 创建从200到400的序列
y <- dnorm(x, mean = posterior_mean, sd = posterior_std)  # 计算后验分布的概率密度
posterior_real <- data.frame(x = x, y = y)

#绘制采样结果直方图
hist_mu <- bayesplot::mcmc_hist(sample_mu, bins=50) +    
  ggplot2::labs(x = "mu", y = "count") +
  papaja::theme_apa()

#绘制采样结果分布图和真实后验分布图
dens_mu_mix <- bayesplot::mcmc_dens(sample_mu) +  #采样结果
  ggplot2::geom_line(data = posterior_real, aes(x = x, y = y), color = "red",size = 0.8) +  #真实后验
  ggplot2::labs(x = "mu", y = "density") +
  papaja::theme_apa()

options(repr.plot.width=16, repr.plot.height=6) 
hist_mu + dens_mu_mix 
