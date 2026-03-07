# AI / ML Flash Cards
# Format: Front=Back

# Key Concepts
Large Language Model (LLM)=A giant text predictor trained on the internet
Tokenization=How text gets chopped into pieces a model can digest
Vectorization (Embeddings)=Turning words into coordinates in meaning-space
Attention Mechanism=How the model decides what to focus on
Self-Supervised Learning=Learning without human labels
Transformer Architecture=The engine powering every modern LLM
Fine-Tuning=Teaching an existing model new tricks
Few-Shot Prompting=Showing examples instead of writing instructions
Retrieval Augmented Generation (RAG)=Giving the model a live reference book
Vector Database=A database that understands meaning, not just exact matches
Model Context Protocol (MCP)=A universal plug for connecting AI to tools
A2A Protocol=How AI agents talk to each other
Context Engineering=The art of filling the model's working memory optimally
AI Agents=LLMs that take actions, not just answer questions
Reinforcement Learning (RL & RLHF)=Training via reward and punishment
Chain of Thought (CoT)=Making the model show its work
Reasoning Models=Models that think before they answer
Multimodal Language Models=Models that see, hear, and read
Small Language Models (SLM)=Powerful models that fit on your phone
Distillation=Compressing a large model's knowledge into a smaller one
Quantization=Making models faster and smaller by lowering precision

# Fundamentals
Supervised Learning=Training a model on labelled data where the correct output is known. The model learns to map inputs to outputs.
Unsupervised Learning=Training on unlabelled data to discover hidden patterns or structure. Examples: clustering, dimensionality reduction.
Reinforcement Learning=An agent learns by interacting with an environment, receiving rewards for good actions and penalties for bad ones.
Overfitting=When a model learns training data too well including noise, performing poorly on unseen data. Fixed by regularisation or more data.
Underfitting=When a model is too simple to capture underlying patterns, performing poorly on both training and test data.
Bias-Variance Tradeoff=High bias = underfitting (too simple). High variance = overfitting (too complex). Goal is to find the right balance.
Feature Engineering=The process of selecting, transforming, and creating input variables to improve model performance.
Train/Val/Test Split=Dividing data into training (learn), validation (tune), and test (final evaluation) sets to prevent overfitting.

# Neural Networks
Neural Network=A computational model loosely inspired by the brain, composed of layers of interconnected nodes (neurons) with learned weights.
Activation Function=A function applied to neuron output to introduce non-linearity. Common examples: ReLU, Sigmoid, Tanh, Softmax.
Backpropagation=The algorithm for training neural networks by computing gradients of the loss function and updating weights via gradient descent.
Gradient Descent=An optimisation algorithm that iteratively adjusts model weights in the direction that reduces the loss function.
Batch Normalisation=Normalising layer inputs during training to stabilise and speed up training by reducing internal covariate shift.
Dropout=A regularisation technique that randomly zeros out neuron outputs during training to prevent co-adaptation and overfitting.
CNN=Convolutional Neural Network — uses convolutional layers to learn spatial features. Primarily used for image recognition tasks.
RNN=Recurrent Neural Network — processes sequential data by maintaining hidden state. Predecessor to Transformers for NLP tasks.

# Large Language Models
Transformer=An architecture using self-attention mechanisms to process sequences in parallel. Foundation of modern LLMs like GPT and BERT.
Attention Mechanism=Allows a model to weigh the importance of different tokens when generating each output token. Core of Transformers.
Self-Attention=Each token attends to all other tokens in the same sequence to capture contextual relationships regardless of distance.
Token=The basic unit of text that LLMs process. Words are split into subword tokens using algorithms like BPE or WordPiece.
Embedding=A dense vector representation of a token or concept in a continuous high-dimensional space where semantics are encoded geometrically.
Fine-Tuning=Further training a pre-trained model on a specific dataset to specialise it for a particular task or domain.
RLHF=Reinforcement Learning from Human Feedback — technique used to align LLMs with human preferences using a reward model trained on human ratings.
Prompt Engineering=Designing input prompts to guide LLM behaviour and elicit desired outputs without changing model weights.
RAG=Retrieval-Augmented Generation — combining a retrieval system with an LLM so the model can reference external knowledge at inference time.
Hallucination=When an LLM generates plausible-sounding but factually incorrect or fabricated information with apparent confidence.
Context Window=The maximum number of tokens an LLM can process in a single forward pass, including both prompt and generated output.
Temperature=A parameter controlling randomness in LLM output. Higher = more creative/random, Lower = more deterministic/focused.