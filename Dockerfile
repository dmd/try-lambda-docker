FROM public.ecr.aws/lambda/python:3.9
RUN pip install numpy
COPY app.py logic.py ${LAMBDA_TASK_ROOT}
RUN chmod +x ${LAMBDA_TASK_ROOT}/logic.py
CMD ["app.lambda_handler"]