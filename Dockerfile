FROM public.ecr.aws/lambda/python:3.9

# Install numpy
RUN pip install numpy

# Copy function code
COPY app.py ${LAMBDA_TASK_ROOT}

# Set the CMD to your handler
CMD ["app.lambda_handler"]